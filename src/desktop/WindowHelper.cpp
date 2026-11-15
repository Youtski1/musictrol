#include "desktop/WindowHelper.h"

#include <QGuiApplication>
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
