#pragma once

#include <QAbstractNativeEventFilter>
#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QtQmlIntegration>

class QQmlEngine;
class QJSEngine;

// Глобальные горячие клавиши на X11: работают из любой программы.
// Сочетания хранятся в настройках (группа Hotkeys), захват — XGrabKey на корневом окне.
class GlobalHotkeys : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{ id, title, sequence (для показа), status: "" | "ok" | "busy" }]
    Q_PROPERTY(QVariantList actions READ actions NOTIFY actionsChanged)

public:
    explicit GlobalHotkeys(QObject *parent = nullptr);
    ~GlobalHotkeys() override;

    static void setInstance(GlobalHotkeys *instance);
    static GlobalHotkeys *create(QQmlEngine *, QJSEngine *);

    QVariantList actions() const;

    // Назначить сочетание по событию клавиатуры из QML (key, modifiers).
    Q_INVOKABLE void assign(const QString &actionId, int key, int modifiers);
    Q_INVOKABLE void clear(const QString &actionId);
    // Пока пользователь вводит новое сочетание — временно снять все захваты.
    Q_INVOKABLE void suspend(bool suspended);

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

signals:
    void actionsChanged();
    void triggered(const QString &actionId);

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

    QList<Action> m_actions;
    bool m_suspended = false;

    static GlobalHotkeys *s_instance;
};
