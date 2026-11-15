#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QVariantMap>
#include <QtQmlIntegration>

#include "core/Track.h"
#include "core/TrackListModel.h"

class QNetworkAccessManager;
class QProcess;
class QQmlEngine;
class QJSEngine;

// Скачанная музыка: yt-dlp сохраняет звук (m4a, без перекодирования) и обложку
// в ~/Музыка/Musictrol; список хранится в downloads.json и играет без интернета.
class Downloads : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Downloads)
    QML_SINGLETON

    Q_PROPERTY(TrackListModel *tracks READ tracks CONSTANT)
    // videoId → процент (0–100) для идущих загрузок; меняется — обновляем кнопки.
    Q_PROPERTY(QVariantMap progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QString folder READ folder CONSTANT)

public:
    // Без значения по умолчанию: иначе QML создаёт свою копию вместо нашей (create()).
    explicit Downloads(QObject *parent);
    ~Downloads() override;

    static void setInstance(Downloads *instance);
    static Downloads *create(QQmlEngine *, QJSEngine *);
    static Downloads *instance() { return s_instance; }

    TrackListModel *tracks() const { return m_tracks; }
    QVariantMap progress() const { return m_progress; }
    int revision() const { return m_revision; }
    QString folder() const;

    Q_INVOKABLE bool isDownloaded(const QString &videoId) const;
    Q_INVOKABLE void download(TrackListModel *model, int index);
    Q_INVOKABLE void remove(int index);
    // Локальный файл трека (если скачан) — чтобы играть без интернета.
    QString localPath(const QString &videoId) const;

signals:
    void progressChanged();
    void changed();
    void finished(const QString &title);
    void failed(const QString &message);

private:
    void load();
    void save() const;
    void fetchCover(const Track &t, const QString &path);
    QString filePath() const;

    TrackListModel *m_tracks;
    QNetworkAccessManager *m_net;
    QHash<QString, QPointer<QProcess>> m_jobs;
    QVariantMap m_progress;
    int m_revision = 0;

    static Downloads *s_instance;
};
