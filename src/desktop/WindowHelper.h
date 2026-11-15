#pragma once

#include <QObject>
#include <QWindow>
#include <QtQmlIntegration>

// Поведение окон-виджетов на X11 (XFCE): слой, все рабочие столы, без панели задач.
class WindowHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Layer { Desktop, Above };
    Q_ENUM(Layer)

    explicit WindowHelper(QObject *parent = nullptr);

    // Главный виджет: под всеми окнами, на всех рабочих столах, не в панели задач.
    Q_INVOKABLE void setupWidgetWindow(QWindow *window, WindowHelper::Layer layer);
    // Закрыт ли прямоугольник окна (в его координатах) другими окнами больше чем наполовину?
    // Нужен, чтобы не обновлять то, чего сейчас никто не видит.
    Q_INVOKABLE bool isCovered(QWindow *window, qreal x, qreal y, qreal width, qreal height) const;
    // Активное окно развёрнуто на весь экран (игра, видео)?
    Q_INVOKABLE bool activeWindowFullscreen() const;
    // Перетаскивание окна без рамки средствами оконного менеджера.
    Q_INVOKABLE void startMove(QWindow *window);
    // Клики принимает только этот прямоугольник окна (остальное — «сквозное»).
    Q_INVOKABLE void setInputRect(QWindow *window, qreal x, qreal y, qreal width, qreal height);

private:
    void applyX11(QWindow *window, Layer layer);
};
