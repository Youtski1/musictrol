#pragma once

#include <QAbstractNativeEventFilter>
#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QtQmlIntegration>

#include <QTimer>

class QQmlEngine;
class QJSEngine;
struct xkb_context;
struct xkb_keymap;
struct xkb_state;

// Глобальные горячие клавиши на X11: работают из любой программы.
// Сочетания хранятся в настройках (группа Hotkeys), захват — XGrabKey на корневом окне.
class GlobalHotkeys : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{ id, title, sequence (для показа), status: "" | "ok" | "busy" }]
    Q_PROPERTY(QVariantList actions READ actions NOTIFY actionsChanged)
    // Интерактивный игровой режим: вся клавиатура временно у нас (без смены активного окна).
    Q_PROPERTY(bool interactive READ interactive NOTIFY interactiveChanged)

public:
    // Без значения по умолчанию: иначе QML создаёт свою копию вместо нашей (create()).
    explicit GlobalHotkeys(QObject *parent);
    ~GlobalHotkeys() override;

    static void setInstance(GlobalHotkeys *instance);
    static GlobalHotkeys *create(QQmlEngine *, QJSEngine *);

    QVariantList actions() const;

    // Назначить сочетание по событию клавиатуры из QML (key, modifiers).
    Q_INVOKABLE void assign(const QString &actionId, int key, int modifiers);
    Q_INVOKABLE void clear(const QString &actionId);
    // Пока пользователь вводит новое сочетание — временно снять все захваты.
    Q_INVOKABLE void suspend(bool suspended);

    bool interactive() const { return m_interactive; }
    // Захватить клавиатуру целиком (XGrabKeyboard). false — занято (например, игрой).
    Q_INVOKABLE bool beginInteractive();
    Q_INVOKABLE void endInteractive();

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

signals:
    void actionsChanged();
    void triggered(const QString &actionId);
    void interactiveChanged();
    // key — имя клавиши X11 (Left, Return, BackSpace, space, Prior, Next…, "SuperKey"),
    // text — напечатанный символ с учётом раскладки (пусто для служебных клавиш).
    void interactiveKey(const QString &key, const QString &text);
    // Сочетание не принято (например, одиночная клавиша без Ctrl/Alt/Super/Shift).
    void assignRejected(const QString &actionId, const QString &reason);

private:
    struct Action {
        QString id;
        QString title;
        QString sequence;   // QKeySequence::PortableText, пусто — не задано
        QString status;
        quint8 keycode = 0;
        quint16 mods = 0;
    };

    void load();
    void save() const;
    void grabAll();
    void ungrabAll();
    bool grab(Action &a);
    void ungrab(const Action &a);
    Action *find(const QString &id);

    void handleInteractiveKey(quint8 keycode, quint16 state);
    void resetXkb();

    QList<Action> m_actions;
    bool m_suspended = false;
    bool m_interactive = false;
    QTimer m_idleTimer;   // страховка: без нажатий клавиатура возвращается игре
    QTimer m_suspendTimer; // страховка: ввод сочетания не может «отпустить» клавиши навсегда
    QTimer m_retryTimer;   // повторно забрать сочетания, которые были заняты
    xkb_context *m_xkbCtx = nullptr;
    xkb_keymap *m_keymap = nullptr;
    xkb_state *m_xkbState = nullptr;

    static GlobalHotkeys *s_instance;
};
