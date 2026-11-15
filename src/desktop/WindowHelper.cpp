#include "desktop/WindowHelper.h"

#include <QGuiApplication>
#include <QCoreApplication>
#include <QRegion>
#include <QPointer>
#include <QTimer>
#include <QWindow>

#include <cmath>
#include <cstdlib>
#include <cstring>

#include <xcb/shape.h>
#include <xcb/xcb.h>

namespace {

// Соединение с X-сервером, если программа реально запущена под X11 (иначе nullptr).
xcb_connection_t *x11Connection()
{
    if (QGuiApplication::platformName() != QLatin1String("xcb"))
        return nullptr;
    auto *x11 = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    return x11 ? x11->connection() : nullptr;
}

xcb_atom_t atom(xcb_connection_t *c, const char *name)
{
    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(c, 0, uint16_t(strlen(name)), name);
    xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(c, cookie, nullptr);
    if (!reply)
        return XCB_ATOM_NONE;
    const xcb_atom_t a = reply->atom;
    free(reply);
    return a;
}

void sendClientMessage(xcb_connection_t *c, xcb_window_t root, xcb_window_t win,
                       xcb_atom_t type, uint32_t d0, uint32_t d1 = 0, uint32_t d2 = 0)
{
    xcb_client_message_event_t ev = {};
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.format = 32;
    ev.window = win;
    ev.type = type;
    ev.data.data32[0] = d0;
    ev.data.data32[1] = d1;
    ev.data.data32[2] = d2;
    ev.data.data32[3] = 1; // источник — обычное приложение
    xcb_send_event(c, 0, root,
                   XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY,
                   reinterpret_cast<const char *>(&ev));
}

} // namespace

WindowHelper::WindowHelper(QObject *parent)
    : QObject(parent)
{
}

void WindowHelper::setupWidgetWindow(QWindow *window, Layer layer)
{
    if (!window)
        return;

    // Оконный менеджер принимает состояния только у показанного окна, а показ
    // асинхронный — применяем сразу и ещё раз чуть позже.
    QPointer<QWindow> w(window);
    applyX11(window, layer);
    QTimer::singleShot(250, this, [this, w, layer] {
        if (w)
            applyX11(w, layer);
    });
}

void WindowHelper::startMove(QWindow *window)
{
    if (window)
        window->startSystemMove();
}

bool WindowHelper::isCovered(QWindow *window, qreal x, qreal y, qreal width, qreal height) const
{
    xcb_connection_t *c = x11Connection();
    if (!c || !window || !window->isVisible())
        return false;
    const xcb_window_t root = xcb_setup_roots_iterator(xcb_get_setup(c)).data->root;
    const xcb_window_t self = xcb_window_t(window->winId());
    const qreal dpr = window->devicePixelRatio();
    const QRect target(QPointF((window->x() + x) * dpr, (window->y() + y) * dpr).toPoint(),
                       QSizeF(width * dpr, height * dpr).toSize());
    if (target.isEmpty())
        return false;

    auto prop = [c](xcb_window_t w, const char *name, xcb_atom_t type, uint32_t len) {
        return xcb_get_property_reply(c, xcb_get_property(c, 0, w, atom(c, name), type, 0, len), nullptr);
    };

    // Текущий рабочий стол
    uint32_t desktop = 0;
    if (xcb_get_property_reply_t *r = prop(root, "_NET_CURRENT_DESKTOP", XCB_ATOM_CARDINAL, 1)) {
        if (xcb_get_property_value_length(r) == 4)
            desktop = *static_cast<uint32_t *>(xcb_get_property_value(r));
        free(r);
    }

    xcb_get_property_reply_t *list = prop(root, "_NET_CLIENT_LIST_STACKING", XCB_ATOM_WINDOW, 4096);
    if (!list)
        return false;
    const auto *wins = static_cast<xcb_window_t *>(xcb_get_property_value(list));
    const int n = xcb_get_property_value_length(list) / 4;

    // Окна идут снизу вверх: учитываем только те, что выше нашего.
    int start = 0;
    for (int i = 0; i < n; ++i)
        if (wins[i] == self) { start = i + 1; break; }

    const xcb_atom_t hidden = atom(c, "_NET_WM_STATE_HIDDEN");
    const xcb_atom_t typeDesktop = atom(c, "_NET_WM_WINDOW_TYPE_DESKTOP");
    const xcb_atom_t typeDock = atom(c, "_NET_WM_WINDOW_TYPE_DOCK");
    const uint32_t ourPid = uint32_t(QCoreApplication::applicationPid());
    QRegion covered;

    for (int i = start; i < n; ++i) {
        const xcb_window_t w = wins[i];
        bool skip = false;
        if (xcb_get_property_reply_t *r = prop(w, "_NET_WM_PID", XCB_ATOM_CARDINAL, 1)) {
            skip = xcb_get_property_value_length(r) == 4 && *static_cast<uint32_t *>(xcb_get_property_value(r)) == ourPid;
            free(r);
        }
        if (!skip) if (xcb_get_property_reply_t *r = prop(w, "_NET_WM_DESKTOP", XCB_ATOM_CARDINAL, 1)) {
            if (xcb_get_property_value_length(r) == 4) {
                const uint32_t d = *static_cast<uint32_t *>(xcb_get_property_value(r));
                skip = d != desktop && d != 0xFFFFFFFF;
            }
            free(r);
        }
        if (!skip) if (xcb_get_property_reply_t *r = prop(w, "_NET_WM_STATE", XCB_ATOM_ATOM, 32)) {
            const auto *a = static_cast<xcb_atom_t *>(xcb_get_property_value(r));
            for (int k = 0; k < xcb_get_property_value_length(r) / 4; ++k)
                skip = skip || a[k] == hidden;
            free(r);
        }
        if (!skip) if (xcb_get_property_reply_t *r = prop(w, "_NET_WM_WINDOW_TYPE", XCB_ATOM_ATOM, 8)) {
            const auto *a = static_cast<xcb_atom_t *>(xcb_get_property_value(r));
            for (int k = 0; k < xcb_get_property_value_length(r) / 4; ++k)
                skip = skip || a[k] == typeDesktop || a[k] == typeDock;
            free(r);
        }
        if (skip)
            continue;

        xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(c, xcb_get_geometry(c, w), nullptr);
        if (!g)
            continue;
        xcb_translate_coordinates_reply_t *t = xcb_translate_coordinates_reply(
            c, xcb_translate_coordinates(c, w, root, 0, 0), nullptr);
        if (t) {
            covered += QRect(t->dst_x, t->dst_y, g->width, g->height).intersected(target);
            free(t);
        }
        free(g);
    }
    free(list);

    qint64 area = 0;
    for (const QRect &r : covered)
        area += qint64(r.width()) * r.height();
    return area * 2 > qint64(target.width()) * target.height();
}

bool WindowHelper::activeWindowFullscreen() const
{
    xcb_connection_t *c = x11Connection();
    if (!c)
        return false;
    const xcb_window_t root = xcb_setup_roots_iterator(xcb_get_setup(c)).data->root;
    xcb_get_property_reply_t *act = xcb_get_property_reply(
        c, xcb_get_property(c, 0, root, atom(c, "_NET_ACTIVE_WINDOW"), XCB_ATOM_WINDOW, 0, 1), nullptr);
    if (!act)
        return false;
    const xcb_window_t win = xcb_get_property_value_length(act) == 4 ? *static_cast<xcb_window_t *>(xcb_get_property_value(act)) : 0;
    free(act);
    if (!win)
        return false;
    const xcb_atom_t full = atom(c, "_NET_WM_STATE_FULLSCREEN");
    xcb_get_property_reply_t *st = xcb_get_property_reply(
        c, xcb_get_property(c, 0, win, atom(c, "_NET_WM_STATE"), XCB_ATOM_ATOM, 0, 32), nullptr);
    bool result = false;
    if (st) {
        const auto *a = static_cast<xcb_atom_t *>(xcb_get_property_value(st));
        for (int i = 0; i < xcb_get_property_value_length(st) / 4; ++i)
            result = result || a[i] == full;
        free(st);
    }
    return result;
}

void WindowHelper::setInputRect(QWindow *window, qreal x, qreal y, qreal width, qreal height)
{
    xcb_connection_t *c = x11Connection();
    if (!c || !window)
        return;
    const qreal dpr = window->devicePixelRatio();
    const xcb_rectangle_t rect = {
        int16_t(std::lround(x * dpr)), int16_t(std::lround(y * dpr)),
        uint16_t(std::lround(width * dpr)), uint16_t(std::lround(height * dpr)),
    };
    xcb_shape_rectangles(c, XCB_SHAPE_SO_SET, XCB_SHAPE_SK_INPUT, XCB_CLIP_ORDERING_UNSORTED,
                         xcb_window_t(window->winId()), 0, 0, 1, &rect);
    xcb_flush(c);
}

void WindowHelper::applyX11(QWindow *window, Layer layer)
{
    xcb_connection_t *c = x11Connection();
    if (!c || !window->isVisible())
        return;

    const xcb_window_t win = xcb_window_t(window->winId());
    const xcb_window_t root = xcb_setup_roots_iterator(xcb_get_setup(c)).data->root;

    const xcb_atom_t netState = atom(c, "_NET_WM_STATE");
    const xcb_atom_t skipTaskbar = atom(c, "_NET_WM_STATE_SKIP_TASKBAR");
    const xcb_atom_t skipPager = atom(c, "_NET_WM_STATE_SKIP_PAGER");
    const xcb_atom_t sticky = atom(c, "_NET_WM_STATE_STICKY");
    const xcb_atom_t below = atom(c, "_NET_WM_STATE_BELOW");
    const xcb_atom_t above = atom(c, "_NET_WM_STATE_ABOVE");
    const xcb_atom_t netDesktop = atom(c, "_NET_WM_DESKTOP");

    constexpr uint32_t Remove = 0, Add = 1;
    sendClientMessage(c, root, win, netState, Add, skipTaskbar, skipPager);
    sendClientMessage(c, root, win, netState, Add, sticky);
    if (layer == Desktop) {
        sendClientMessage(c, root, win, netState, Remove, above);
        sendClientMessage(c, root, win, netState, Add, below);
    } else {
        sendClientMessage(c, root, win, netState, Remove, below);
        sendClientMessage(c, root, win, netState, Add, above);
    }
    sendClientMessage(c, root, win, netDesktop, 0xFFFFFFFF); // все рабочие столы
    xcb_flush(c);
}
