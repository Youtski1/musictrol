#include "core/Lyrics.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrlQuery>
#include <algorithm>
#include <cmath>

Lyrics *Lyrics::s_instance = nullptr;

namespace {
QString cleanup(QString s)
{
    // Убираем (Official Video), [Lyrics], «Премьера клипа» и т.п.
    s.remove(QRegularExpression(QStringLiteral(R"(\([^)]*\)|\[[^\]]*\]|【[^】]*】)")));
    static const QRegularExpression junk(
        QStringLiteral(R"(\b(official|music|video|audio|lyrics?|lyric video|clip|hd|4k|премьера|клип(а)?|текст)\b)"),
        QRegularExpression::CaseInsensitiveOption | QRegularExpression::UseUnicodePropertiesOption);
    s.remove(junk);
    s.replace(QRegularExpression(QStringLiteral(R"(\s*(ft\.?|feat\.?)\s.*$)"), QRegularExpression::CaseInsensitiveOption), QString());
    s.remove(QRegularExpression(QStringLiteral(R"([|«»"“”])")));
    return s.simplified().remove(QRegularExpression(QStringLiteral(R"(^[\s\-–—:]+|[\s\-–—:]+$)")));
}
} // namespace

Lyrics::Lyrics(QObject *parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
{
}

void Lyrics::setInstance(Lyrics *instance)
{
    s_instance = instance;
}

Lyrics *Lyrics::create(QQmlEngine *, QJSEngine *)
{
    Q_ASSERT(s_instance);
    QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
    return s_instance;
}

void Lyrics::guessArtistTitle(const QString &rawTitle, const QString &channel, QString &artist, QString &title)
{
    static const QRegularExpression sep(QStringLiteral(R"(\s+[-–—]\s+)"));
    const QStringList parts = rawTitle.split(sep);
    if (parts.size() >= 2) {
        artist = cleanup(parts.first());
        title = cleanup(parts.mid(1).join(QLatin1Char(' ')));
    } else {
        title = cleanup(rawTitle);
        artist = channel;
        artist.remove(QRegularExpression(QStringLiteral(R"(\s*-\s*Topic$|VEVO$|\s*Official$)"), QRegularExpression::CaseInsensitiveOption));
        artist = artist.simplified();
    }
}

QString Lyrics::cachePath(const QString &videoId) const
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/lyrics/") + videoId + QStringLiteral(".lrc");
}

void Lyrics::loadFor(const QString &videoId, const QString &rawTitle, const QString &channel,
                     double duration, const QString &localFile)
{
    if (videoId == m_videoId && m_status != QLatin1String("idle"))
        return;
    if (m_reply) {
        m_reply->abort();
        m_reply = nullptr;
    }
    m_videoId = videoId;
    m_localFile = localFile;
    m_lines.clear();
    m_times.clear();
    m_synced = false;

    if (videoId.isEmpty()) {
        setStatus(QStringLiteral("idle"));
        return;
    }

    // 1) .lrc рядом со скачанным файлом, 2) кэш, 3) сеть.
    const QStringList candidates = {
        localFile.isEmpty() ? QString() : QFileInfo(localFile).path() + QLatin1Char('/') + QFileInfo(localFile).completeBaseName() + QStringLiteral(".lrc"),
        cachePath(videoId),
    };
    for (const QString &path : candidates) {
        QFile f(path);
        if (!path.isEmpty() && f.open(QIODevice::ReadOnly)) {
            const QString text = QString::fromUtf8(f.readAll());
            if (text.trimmed() == QLatin1String("#notfound")) {
                setStatus(QStringLiteral("notfound"));
                return;
            }
            setResult(text, text.contains(QRegularExpression(QStringLiteral(R"(^\[\d+:\d+)"), QRegularExpression::MultilineOption)));
            return;
        }
    }

    setStatus(QStringLiteral("loading"));
    QString artist, title;
    guessArtistTitle(rawTitle, channel, artist, title);

    QUrl url(QStringLiteral("https://lrclib.net/api/search"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("q"), (artist + QLatin1Char(' ') + title).trimmed());
    url.setQuery(q);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Musictrol (desktop music widget)"));
    QNetworkReply *reply = m_net->get(req);
    m_reply = reply;

    connect(reply, &QNetworkReply::finished, this, [this, reply, videoId, duration] {
        reply->deleteLater();
        if (reply != m_reply || videoId != m_videoId)
            return;
        m_reply = nullptr;

        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        // Лучший вариант: с таймингами и близкий по длительности.
        QJsonObject best;
        double bestScore = -1e9;
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            const bool hasSynced = !o.value(QLatin1String("syncedLyrics")).toString().isEmpty();
            const bool hasPlain = !o.value(QLatin1String("plainLyrics")).toString().isEmpty();
            if (!hasSynced && !hasPlain)
                continue;
            const double d = o.value(QLatin1String("duration")).toDouble();
            const double diff = duration > 0 && d > 0 ? std::abs(d - duration) : 5;
            if (diff > 25)
                continue; // явно другая песня
            const double score = (hasSynced ? 100 : 0) - diff;
            if (score > bestScore) {
                bestScore = score;
                best = o;
            }
        }

        if (best.isEmpty()) {
            QDir().mkpath(QFileInfo(cachePath(videoId)).path());
            QFile f(cachePath(videoId));
            if (reply->error() == QNetworkReply::NoError && f.open(QIODevice::WriteOnly))
                f.write("#notfound\n"); // не искать снова при каждом запуске
            setStatus(QStringLiteral("notfound"));
            return;
        }

        const QString synced = best.value(QLatin1String("syncedLyrics")).toString();
        const QString text = synced.isEmpty() ? best.value(QLatin1String("plainLyrics")).toString() : synced;
        QDir().mkpath(QFileInfo(cachePath(videoId)).path());
        for (const QString &path : {cachePath(videoId),
                                    m_localFile.isEmpty() ? QString()
                                    : QFileInfo(m_localFile).path() + QLatin1Char('/') + QFileInfo(m_localFile).completeBaseName() + QStringLiteral(".lrc")}) {
            QFile f(path);
            if (!path.isEmpty() && f.open(QIODevice::WriteOnly))
                f.write(text.toUtf8());
        }
        setResult(text, !synced.isEmpty());
    });
}

void Lyrics::setResult(const QString &text, bool synced)
{
    m_synced = synced;
    m_lines.clear();
    m_times.clear();
    if (synced) {
        parseLrc(text);
    } else {
        for (const QString &l : text.split(QLatin1Char('\n')))
            m_lines.append(QVariantMap{{QStringLiteral("time"), -1}, {QStringLiteral("text"), l.trimmed()}});
    }
    m_status = m_lines.isEmpty() ? QStringLiteral("notfound") : QStringLiteral("found");
    emit changed();
}

void Lyrics::parseLrc(const QString &lrc)
{
    static const QRegularExpression tag(QStringLiteral(R"(\[(\d+):(\d+(?:\.\d+)?)\])"));
    QList<QPair<double, QString>> items;
    for (const QString &raw : lrc.split(QLatin1Char('\n'))) {
        QString line = raw;
        QList<double> times;
        auto it = tag.globalMatch(line);
        while (it.hasNext()) {
            const auto m = it.next();
            times.append(m.captured(1).toDouble() * 60 + m.captured(2).toDouble());
        }
        if (times.isEmpty())
            continue;
        line.remove(tag);
        line = line.trimmed();
        for (double t : times)
            items.append({t, line.isEmpty() ? QStringLiteral("♪") : line});
    }
    std::sort(items.begin(), items.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    for (const auto &[t, text] : items) {
        m_times.append(t);
        m_lines.append(QVariantMap{{QStringLiteral("time"), t}, {QStringLiteral("text"), text}});
    }
}

int Lyrics::lineAt(double position) const
{
    if (!m_synced || m_times.isEmpty())
        return -1;
    // Чуть раньше — строка появляется вместе с голосом, а не после.
    const auto it = std::upper_bound(m_times.begin(), m_times.end(), position + 0.25);
    return int(it - m_times.begin()) - 1;
}

void Lyrics::setStatus(const QString &s)
{
    m_status = s;
    emit changed();
}
