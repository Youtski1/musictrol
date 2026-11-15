#include "desktop/GlobalHotkeys.h"

#include <QGuiApplication>
#include <QJSEngine>
#include <QKeySequence>
#include <QQmlEngine>
#include <QSettings>

#include <cstdlib>

#include <xcb/xcb.h>
#include <xcb/xcb_keysyms.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbcommon-x11.h>

namespace {

xcb_connection_t *x11Connection()
{
    if (QGuiApplication::platformName() != QLatin1String("xcb"))
        return nullptr;
    auto *x11 = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    return x11 ? x11->connection() : nullptr;
}

xcb_window_t rootWindow(xcb_connection_t *c)
{
    return xcb_setup_roots_iterator(xcb_get_setup(c)).data->root;
}

constexpr quint16 kRelevantMods = XCB_MOD_MASK_SHIFT | XCB_MOD_MASK_CONTROL | XCB_MOD_MASK_1 | XCB_MOD_MASK_4;
// NumLock (Mod2) и CapsLock не должны мешать срабатыванию.
constexpr quint16 kIgnoredMods[] = {0, XCB_MOD_MASK_LOCK, XCB_MOD_MASK_2, XCB_MOD_MASK_LOCK | XCB_MOD_MASK_2};

quint32 keysymFor(int key)
{
    if (key >= Qt::Key_A && key <= Qt::Key_Z)
        return 'a' + (key - Qt::Key_A);
    if (key >= Qt::Key_0 && key <= Qt::Key_9)
        return quint32(key);
    if (key >= Qt::Key_F1 && key <= Qt::Key_F24)
        return 0xffbe + (key - Qt::Key_F1);
    switch (key) {
    case Qt::Key_Space: return 0x20;
    case Qt::Key_Left: return 0xff51;
    case Qt::Key_Up: return 0xff52;
    case Qt::Key_Right: return 0xff53;
    case Qt::Key_Down: return 0xff54;
    case Qt::Key_Return:
    case Qt::Key_Enter: return 0xff0d;
    case Qt::Key_Tab: return 0xff09;
    case Qt::Key_Backspace: return 0xff08;
    case Qt::Key_Home: return 0xff50;
    case Qt::Key_End: return 0xff57;
    case Qt::Key_PageUp: return 0xff55;
    case Qt::Key_PageDown: return 0xff56;
    case Qt::Key_Insert: return 0xff63;
    case Qt::Key_Delete: return 0xffff;
    case Qt::Key_Pause: return 0xff13;
    case Qt::Key_Print: return 0xff61;
    case Qt::Key_MediaPlay:
    case Qt::Key_MediaTogglePlayPause: return 0x1008ff14;
    case Qt::Key_MediaStop: return 0x1008ff15;
    case Qt::Key_MediaPrevious: return 0x1008ff16;
    case Qt::Key_MediaNext: return 0x1008ff17;
    case Qt::Key_VolumeDown: return 0x1008ff11;
    case Qt::Key_VolumeMute: return 0x1008ff12;
    case Qt::Key_VolumeUp: return 0x1008ff13;
    default: break;
    }
    if (key >= 0x21 && key <= 0x7e)
        return QChar(key).toLower().unicode();
    return 0;
}

quint16 xcbModsFor(Qt::KeyboardModifiers m)
{
    quint16 r = 0;
    if (m & Qt::ShiftModifier) r |= XCB_MOD_MASK_SHIFT;
    if (m & Qt::ControlModifier) r |= XCB_MOD_MASK_CONTROL;
    if (m & Qt::AltModifier) r |= XCB_MOD_MASK_1;
    if (m & Qt::MetaModifier) r |= XCB_MOD_MASK_4;
    return r;
}

bool isModifierKey(int key)
{
    switch (key) {
    case Qt::Key_Shift: case Qt::Key_Control: case Qt::Key_Alt: case Qt::Key_Meta:
    case Qt::Key_Super_L: case Qt::Key_Super_R: case Qt::Key_AltGr: case Qt::Key_CapsLock:
    case Qt::Key_NumLock: case Qt::Key_Hyper_L: case Qt::Key_Hyper_R:
        return true;
    default:
        return false;
    }
}

QString displayText(const QString &portable)
{
    if (portable.isEmpty())
        return {};
    QString s = QKeySequence::fromString(portable, QKeySequence::PortableText).toString(QKeySequence::NativeText);
    s.replace(QLatin1String("Meta"), QLatin1String("Super"));
    return s;
}

} // namespace

GlobalHotkeys *GlobalHotkeys::s_instance = nullptr;

GlobalHotkeys::GlobalHotkeys(QObject *parent)
    : QObject(parent)
{
    m_actions = {
        {QStringLiteral("panel"), tr("Открыть музыку (поиск)"), QStringLiteral("Meta+M")},
        {QStringLiteral("playPause"), tr("Пауза / играть"), {}},
        {QStringLiteral("next"), tr("Следующий трек"), {}},
        {QStringLiteral("prev"), tr("Предыдущий трек"), {}},
        {QStringLiteral("volUp"), tr("Громче"), {}},
        {QStringLiteral("volDown"), tr("Тише"), {}},
        {QStringLiteral("wave"), tr("Капсула: перемотка сверху"), {}},
    };
    load();
    qApp->installNativeEventFilter(this);
    grabAll();

    m_idleTimer.setSingleShot(true);
    m_idleTimer.setInterval(30000);
    connect(&m_idleTimer, &QTimer::timeout, this, &GlobalHotkeys::endInteractive);
}

GlobalHotkeys::~GlobalHotkeys()
{
    endInteractive();
    resetXkb();
    qApp->removeNativeEventFilter(this);
    ungrabAll();
    if (s_instance == this)
        s_instance = nullptr;
}

void GlobalHotkeys::setInstance(GlobalHotkeys *instance)
{
    s_instance = instance;
}

GlobalHotkeys *GlobalHotkeys::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

QVariantList GlobalHotkeys::actions() const
{
    QVariantList list;
    for (const Action &a : m_actions) {
        list.append(QVariantMap{
            {QStringLiteral("id"), a.id},
            {QStringLiteral("title"), a.title},
            {QStringLiteral("sequence"), displayText(a.sequence)},
            {QStringLiteral("status"), a.status},
        });
    }
    return list;
}

GlobalHotkeys::Action *GlobalHotkeys::find(const QString &id)
{
    for (Action &a : m_actions) {
        if (a.id == id)
            return &a;
    }
    return nullptr;
}

void GlobalHotkeys::assign(const QString &actionId, int key, int modifiers)
{
    Action *a = find(actionId);
    if (!a || isModifierKey(key) || key == 0)
        return;

    const QKeyCombination combo(Qt::KeyboardModifiers(modifiers & (Qt::ShiftModifier | Qt::ControlModifier
                                                                   | Qt::AltModifier | Qt::MetaModifier)),
                                Qt::Key(key));
    const QString seq = QKeySequence(combo).toString(QKeySequence::PortableText);

    // Одно сочетание — одно действие: снимаем его с других.
    for (Action &other : m_actions) {
        if (&other != a && other.sequence == seq) {
            ungrab(other);
            other.sequence.clear();
            other.status.clear();
        }
    }
    ungrab(*a);
    a->sequence = seq;
    a->status.clear();
    if (!m_suspended)
        grab(*a);
    save();
    emit actionsChanged();
}

void GlobalHotkeys::clear(const QString &actionId)
{
    Action *a = find(actionId);
    if (!a)
        return;
    ungrab(*a);
    a->sequence.clear();
    a->status.clear();
    save();
    emit actionsChanged();
}

void GlobalHotkeys::suspend(bool suspended)
{
    if (m_suspended == suspended)
        return;
    m_suspended = suspended;
    if (suspended)
        ungrabAll();
    else
        grabAll();
    emit actionsChanged();
}

void GlobalHotkeys::load()
{
    QSettings s;
    s.beginGroup(QStringLiteral("Hotkeys"));
    for (Action &a : m_actions) {
        if (s.contains(a.id))
            a.sequence = s.value(a.id).toString();
    }
}

void GlobalHotkeys::save() const
{
    QSettings s;
    s.beginGroup(QStringLiteral("Hotkeys"));
    for (const Action &a : m_actions)
        s.setValue(a.id, a.sequence);
}

void GlobalHotkeys::grabAll()
{
    for (Action &a : m_actions)
        grab(a);
}

void GlobalHotkeys::ungrabAll()
{
    for (const Action &a : m_actions)
        ungrab(a);
}

bool GlobalHotkeys::grab(Action &a)
{
    a.keycode = 0;
    a.mods = 0;
    a.status.clear();
    if (a.sequence.isEmpty())
        return false;

    xcb_connection_t *c = x11Connection();
    if (!c)
        return false;

    const QKeySequence ks = QKeySequence::fromString(a.sequence, QKeySequence::PortableText);
    if (ks.isEmpty())
        return false;
    const QKeyCombination combo = ks[0];
    const quint32 sym = keysymFor(combo.key());
    if (!sym) {
        a.status = QStringLiteral("busy");
        return false;
    }

    xcb_key_symbols_t *syms = xcb_key_symbols_alloc(c);
    xcb_keycode_t *codes = xcb_key_symbols_get_keycode(syms, sym);
    const xcb_keycode_t code = codes ? codes[0] : 0;
    free(codes);
    xcb_key_symbols_free(syms);
    if (!code) {
        a.status = QStringLiteral("busy");
        return false;
    }

    const quint16 mods = xcbModsFor(combo.keyboardModifiers());
    const xcb_window_t root = rootWindow(c);
    bool ok = true;
    for (quint16 extra : kIgnoredMods) {
        xcb_void_cookie_t ck = xcb_grab_key_checked(c, 1, root, mods | extra, code,
                                                    XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC);
        if (xcb_generic_error_t *err = xcb_request_check(c, ck)) {
            free(err);
            ok = false;
        }
    }
    if (!ok) {
        // Сочетание уже занято другой программой — откатываем частичный захват.
        for (quint16 extra : kIgnoredMods)
            xcb_ungrab_key(c, code, root, mods | extra);
        xcb_flush(c);
        a.status = QStringLiteral("busy");
        return false;
    }
    xcb_flush(c);
    a.keycode = code;
    a.mods = mods;
    a.status = QStringLiteral("ok");
    return true;
}

void GlobalHotkeys::ungrab(const Action &a)
{
    if (!a.keycode)
        return;
    xcb_connection_t *c = x11Connection();
    if (!c)
        return;
    const xcb_window_t root = rootWindow(c);
    for (quint16 extra : kIgnoredMods)
        xcb_ungrab_key(c, a.keycode, root, a.mods | extra);
    xcb_flush(c);
}

void GlobalHotkeys::resetXkb()
{
    if (m_xkbState) xkb_state_unref(m_xkbState);
    if (m_keymap) xkb_keymap_unref(m_keymap);
    if (m_xkbCtx) xkb_context_unref(m_xkbCtx);
    m_xkbState = nullptr;
    m_keymap = nullptr;
    m_xkbCtx = nullptr;
}

bool GlobalHotkeys::beginInteractive()
{
    if (m_interactive)
        return true;
    xcb_connection_t *c = x11Connection();
    if (!c)
        return false;

    // Раскладки читаем заново — вдруг пользователь их менял.
    resetXkb();
    if (xkb_x11_setup_xkb_extension(c, XKB_X11_MIN_MAJOR_XKB_VERSION, XKB_X11_MIN_MINOR_XKB_VERSION,
                                    XKB_X11_SETUP_XKB_EXTENSION_NO_FLAGS, nullptr, nullptr, nullptr, nullptr)) {
        m_xkbCtx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
        const int32_t dev = xkb_x11_get_core_keyboard_device_id(c);
        if (m_xkbCtx && dev >= 0)
            m_keymap = xkb_x11_keymap_new_from_device(m_xkbCtx, c, dev, XKB_KEYMAP_COMPILE_NO_FLAGS);
        if (m_keymap)
            m_xkbState = xkb_state_new(m_keymap);
    }
    if (!m_xkbState) {
        resetXkb();
        return false;
    }

    xcb_grab_keyboard_reply_t *r = xcb_grab_keyboard_reply(
        c, xcb_grab_keyboard(c, 1, rootWindow(c), XCB_CURRENT_TIME, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC), nullptr);
    const bool ok = r && r->status == XCB_GRAB_STATUS_SUCCESS;
    free(r);
    if (!ok)
        return false;

    m_interactive = true;
    m_idleTimer.start();
    emit interactiveChanged();
    return true;
}

void GlobalHotkeys::endInteractive()
{
    if (!m_interactive)
        return;
    if (xcb_connection_t *c = x11Connection()) {
        xcb_ungrab_keyboard(c, XCB_CURRENT_TIME);
        xcb_flush(c);
    }
    m_interactive = false;
    m_idleTimer.stop();
    emit interactiveChanged();
}

void GlobalHotkeys::handleInteractiveKey(quint8 keycode, quint16 state)
{
    m_idleTimer.start();
    // Модификаторы X → xkb (Caps Lock — «зафиксированный»), группа раскладки — биты 13–14.
    const quint32 mods = state & 0xff;
    const xkb_layout_index_t group = (state >> 13) & 3;
    xkb_state_update_mask(m_xkbState, mods & ~XCB_MOD_MASK_LOCK, 0, mods & XCB_MOD_MASK_LOCK, 0, 0, group);

    const xkb_keysym_t sym = xkb_state_key_get_one_sym(m_xkbState, keycode);
    char name[64] = {0};
    xkb_keysym_get_name(sym, name, sizeof name);

    QString key = QString::fromLatin1(name);
    QString text;
    if (state & XCB_MOD_MASK_4) {
        key = QStringLiteral("SuperKey"); // Super+что-угодно — выйти из режима
    } else if (!(state & XCB_MOD_MASK_CONTROL)) {
        char buf[16] = {0};
        const int n = xkb_state_key_get_utf8(m_xkbState, keycode, buf, sizeof buf);
        if (n > 0) {
            text = QString::fromUtf8(buf, n);
            if (!text.at(0).isPrint())
                text.clear();
        }
    }
    QMetaObject::invokeMethod(this, [this, key, text] { emit interactiveKey(key, text); }, Qt::QueuedConnection);
}

bool GlobalHotkeys::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *)
{
    if (eventType != "xcb_generic_event_t")
        return false;
    auto *ev = static_cast<xcb_generic_event_t *>(message);
    const quint8 type = ev->response_type & ~0x80;

    // Интерактивный режим: все клавиши — нам.
    if (m_interactive && (type == XCB_KEY_PRESS || type == XCB_KEY_RELEASE)) {
        if (type == XCB_KEY_PRESS) {
            auto *k = reinterpret_cast<xcb_key_press_event_t *>(ev);
            handleInteractiveKey(k->detail, k->state);
        }
        return true;
    }

    if (m_suspended || type != XCB_KEY_PRESS)
        return false;

    auto *k = reinterpret_cast<xcb_key_press_event_t *>(ev);
    const quint16 state = k->state & kRelevantMods;
    for (const Action &a : m_actions) {
        if (a.keycode && a.keycode == k->detail && a.mods == state) {
            const QString id = a.id;
            QMetaObject::invokeMethod(this, [this, id] { emit triggered(id); }, Qt::QueuedConnection);
            return true;
        }
    }
    return false;
}
