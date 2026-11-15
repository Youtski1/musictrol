#include "core/Downloads.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

Downloads *Downloads::s_instance = nullptr;

namespace {
// Имя файла без символов, которые мешают файловой системе.
QString safeName(QString s)
{
    s.replace(QRegularExpression(QStringLiteral(R"([/\\:*?"<>|\x00-\x1f])")), QStringLiteral(" "));
    s = s.simplified();
    return s.left(120);
}
} // namespace

Downloads::Downloads(QObject *parent)
    : QObject(parent)
    , m_tracks(new TrackListModel(this))
    , m_net(new QNetworkAccessManager(this))
{
    load();
}

Downloads::~Downloads()
{
    for (const QPointer<QProcess> &p : std::as_const(m_jobs)) {
        if (p) {
            p->disconnect(this);
            p->kill();
            p->waitForFinished(500);
        }
    }
    if (s_instance == this)
        s_instance = nullptr;
}

void Downloads::setInstance(Downloads *instance)
{
    s_instance = instance;
}

Downloads *Downloads::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

QString Downloads::folder() const
{
    QString music = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    if (music.isEmpty())
        music = QDir::homePath() + QStringLiteral("/Music");
    return music + QStringLiteral("/Musictrol");
}

QString Downloads::filePath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/downloads.json");
}

bool Downloads::isDownloaded(const QString &videoId) const
{
    return !videoId.isEmpty() && m_tracks->indexOfVideo(videoId) >= 0;
}

QString Downloads::localPath(const QString &videoId) const
{
    const int i = m_tracks->indexOfVideo(videoId);
    return i >= 0 ? m_tracks->at(i).url : QString();
}

void Downloads::download(TrackListModel *model, int index)
{
    if (!model)
        return;
    const Track src = model->at(index);
    if (!src.isValid() || src.videoId.isEmpty() || isDownloaded(src.videoId) || m_jobs.contains(src.videoId))
        return;
    if (QStandardPaths::findExecutable(QStringLiteral("yt-dlp")).isEmpty()) {
        emit failed(tr("Не найден yt-dlp"));
        return;
    }

    const QString dir = folder();
    QDir().mkpath(dir + QStringLiteral("/.covers"));
    const QString base = safeName((src.artist.isEmpty() ? QString() : src.artist + QStringLiteral(" - ")) + src.title);
    const QString outTemplate = dir + QLatin1Char('/') + base + QStringLiteral(" [%(id)s].%(ext)s");

    auto *proc = new QProcess(this);
    m_jobs.insert(src.videoId, proc);
    m_progress.insert(src.videoId, 0);
    emit progressChanged();

    // Процент из строк «dl:  42.3%».
    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, id = src.videoId] {
        while (proc->canReadLine()) {
            const QString line = QString::fromUtf8(proc->readLine()).trimmed();
            if (line.startsWith(QLatin1String("dl:"))) {
                bool ok = false;
                const double pct = line.mid(3).remove(QLatin1Char('%')).trimmed().toDouble(&ok);
                if (ok) {
                    m_progress.insert(id, int(pct));
                    emit progressChanged();
                }
            } else if (line.startsWith(QLatin1String("file:"))) {
                proc->setProperty("outFile", line.mid(5).trimmed());
            }
        }
    });

    connect(proc, &QProcess::finished, this, [this, proc, src](int code, QProcess::ExitStatus status) {
        proc->deleteLater();
        m_jobs.remove(src.videoId);
        m_progress.remove(src.videoId);
        emit progressChanged();

        const QString out = proc->property("outFile").toString();
        if (status != QProcess::NormalExit || code != 0 || out.isEmpty() || !QFileInfo::exists(out)) {
            const QString err = QString::fromUtf8(proc->readAllStandardError()).trimmed().section(QLatin1Char('\n'), -1);
            emit failed(err.isEmpty() ? tr("Не удалось скачать «%1»").arg(src.title) : err);
            return;
        }

        Track t = src;
        t.url = out;
        const QString cover = folder() + QStringLiteral("/.covers/") + src.videoId + QStringLiteral(".jpg");
        t.thumbnail = QUrl::fromLocalFile(cover).toString();
        fetchCover(src, cover);
        m_tracks->prepend(t);
        ++m_revision;
        save();
        emit changed();
        emit finished(src.title);
    });

    proc->start(QStringLiteral("yt-dlp"), {
        QStringLiteral("-f"), QStringLiteral("bestaudio[ext=m4a]/bestaudio"),
        QStringLiteral("-x"), QStringLiteral("--audio-format"), QStringLiteral("m4a"),
        QStringLiteral("--embed-metadata"),
        QStringLiteral("--no-playlist"),
        QStringLiteral("--newline"),
        QStringLiteral("--color"), QStringLiteral("never"),
        QStringLiteral("--progress"), // --print иначе выключает прогресс
        QStringLiteral("--progress-template"), QStringLiteral("download:dl:%(progress._percent_str)s"),
        QStringLiteral("--print"), QStringLiteral("after_move:file:%(filepath)s"),
        QStringLiteral("-o"), outTemplate,
        src.url,
    });
}

void Downloads::fetchCover(const Track &t, const QString &path)
{
    // Сначала большая обложка, если её нет — обычная.
    const QString big = QString(t.thumbnail).replace(QLatin1String("mqdefault"), QLatin1String("hq720"));
    QNetworkReply *r = m_net->get(QNetworkRequest(QUrl(big)));
    connect(r, &QNetworkReply::finished, this, [this, r, t, path] {
        r->deleteLater();
        QByteArray data = r->error() == QNetworkReply::NoError ? r->readAll() : QByteArray();
        if (data.isEmpty()) {
            QNetworkReply *r2 = m_net->get(QNetworkRequest(QUrl(t.thumbnail)));
            connect(r2, &QNetworkReply::finished, this, [this, r2, path] {
                r2->deleteLater();
                QFile f(path);
                if (r2->error() == QNetworkReply::NoError && f.open(QIODevice::WriteOnly))
                    f.write(r2->readAll());
                ++m_revision;
                emit changed();
            });
            return;
        }
        QFile f(path);
        if (f.open(QIODevice::WriteOnly))
            f.write(data);
        ++m_revision;
        emit changed();
    });
}

void Downloads::remove(int index)
{
    const Track t = m_tracks->at(index);
    if (!t.isValid())
        return;
    QFile::remove(t.url);
    QFile::remove(QUrl(t.thumbnail).toLocalFile());
    m_tracks->removeAt(index);
    ++m_revision;
    save();
    emit changed();
}

void Downloads::load()
{
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly))
        return;
    TrackList list;
    for (const QJsonValue &v : QJsonDocument::fromJson(f.readAll()).array()) {
        const Track t = Track::fromJson(v.toObject());
        if (t.isValid() && QFileInfo::exists(t.url)) // файл удалили руками — убираем из списка
            list.append(t);
    }
    m_tracks->setTracks(list);
}

void Downloads::save() const
{
    QJsonArray arr;
    for (const Track &t : m_tracks->tracks())
        arr.append(t.toJson());
    QDir().mkpath(QFileInfo(filePath()).absolutePath());
    QSaveFile f(filePath());
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(arr).toJson(QJsonDocument::Compact));
    f.commit();
}
