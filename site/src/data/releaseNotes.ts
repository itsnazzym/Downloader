export const releaseNotes = {
  fr: {
    title: 'Notes de version',
    description: 'Retrouvez les nouveautés, améliorations et corrections de TapLoad.',
    eyebrow: 'TapLoad · Windows',
    heading: 'Ce qui a changé.',
    intro: 'Les nouveautés et corrections intégrées aux versions publiées de TapLoad.',
    latest: 'Version la plus récente',
    release: 'Version',
    back: 'Retour à l’accueil',
    browse: 'Explorer les plugins',
    releases: [
      {
        version: '1.0.20',
        date: '25 septembre 2026',
        isoDate: '2026-09-25',
        latest: true,
        sections: [
          {
            title: 'Corrections',
            items: [
              'Mise à jour de yt-dlp pour suivre les changements récents de l’extraction vidéo TikTok.',
              'Meilleure distinction entre les restrictions de confidentialité TikTok, les limites réseau et les captchas.',
              'Les vidéos définitivement privées ou indisponibles sont retirées des échecs et des archives.',
            ],
          },
        ],
      },
      {
        version: '1.0.19',
        date: '25 septembre 2026',
        isoDate: '2026-09-25',
        sections: [
          {
            title: 'Nouveautés',
            items: [
              'Service Tor Expert Bundle facultatif sur Windows. Les téléchargements via Tor s’arrêtent si le proxy SOCKS5 n’est pas disponible.',
              'Archives TikTok enrichies d’un lecteur vertical intégré et d’une vue avec affiches de collections.',
              'Nouvelle section d’utilisation du stockage avec analyse des dossiers, graphique et détails.',
            ],
          },
          {
            title: 'Améliorations',
            items: [
              'Archives TikTok simplifiées, avec des actions clarifiées et le retrait des commandes inachevées ou en double.',
              'Statistiques accessibles depuis le dock et Organisation intelligente depuis la barre latérale.',
              'Tris de taille plus fiables et traductions étendues aux notifications, menus et réglages.',
            ],
          },
          {
            title: 'Corrections',
            items: [
              'Importation, synchronisation et nouvel essai des collections TikTok plus fiables, y compris avec les liens partagés et la pagination.',
              'Lecture TikTok intégrée plus fluide, avec préchargement des vidéos suivantes et états d’accès mieux expliqués.',
              'Extension X renforcée pour mieux gérer les publications sans vidéo, suspendues ou contenant un lien Discord.',
            ],
          },
        ],
      },
      {
        version: '1.0.6',
        date: '27 août 2026',
        isoDate: '2026-08-27',
        sections: [
          {
            title: 'Nouveautés et corrections',
            items: [
              'Ajout du flux X expérimental Gobird, activable dans les réglages avancés.',
              'Améliorations de la signature Firefox et du processus de publication Windows.',
            ],
          },
        ],
      },
      {
        version: '1.0.5',
        date: '19 mars 2026',
        isoDate: '2026-03-19',
        sections: [{ title: 'Publication', items: ['Publication de l’application Windows et des extensions de navigateur.'] }],
      },
      {
        version: '1.0.4',
        date: '15 février 2026',
        isoDate: '2026-02-15',
        sections: [{ title: 'Nouveautés', items: ['Ajout de l’installeur Windows et des bases de l’application, avec traductions françaises, anglaises et arabes.'] }],
      },
      {
        version: '1.0.3',
        date: '1 février 2026',
        isoDate: '2026-02-01',
        sections: [{ title: 'Nouveautés', items: ['Ajout de la détection des liens, du choix des vidéos et de leur envoi vers la file de téléchargements.'] }],
      },
      {
        version: '1.0.0',
        date: '31 janvier 2026',
        isoDate: '2026-01-31',
        sections: [{ title: 'Première version', items: ['Première version du téléchargeur Windows, du pont WebSocket local et des extensions Chrome et Firefox.'] }],
      },
    ],
  },
  en: {
    title: 'Release notes',
    description: 'See what is new, improved, and fixed in TapLoad.',
    eyebrow: 'TapLoad · Windows',
    heading: 'What changed.',
    intro: 'New features, improvements, and fixes included in TapLoad releases.',
    latest: 'Latest version',
    release: 'Version',
    back: 'Back to home',
    browse: 'Explore plugins',
    releases: [
      {
        version: '1.0.20',
        date: 'September 25, 2026',
        isoDate: '2026-09-25',
        latest: true,
        sections: [{
          title: 'Fixes',
          items: [
            'Updated yt-dlp to keep up with recent changes to TikTok video extraction.',
            'Better distinction between TikTok privacy restrictions, network limits, and captchas.',
            'Videos confirmed permanently private or unavailable are removed from failed downloads and archives.',
          ],
        }],
      },
      {
        version: '1.0.19',
        date: 'September 25, 2026',
        isoDate: '2026-09-25',
        sections: [
          {
            title: 'New',
            items: [
              'Optional Tor Expert Bundle service on Windows. Downloads through Tor stop if the SOCKS5 proxy is unavailable.',
              'TikTok Archives now include an in-app vertical player and a collection poster view.',
              'A new Storage Usage section scans folders and presents a chart with details.',
            ],
          },
          {
            title: 'Improvements',
            items: [
              'Simplified TikTok Archives with clearer actions and unfinished or duplicate controls removed.',
              'Statistics are available from the dock and Smart Organizer from the sidebar.',
              'More reliable size sorting and expanded translations for notifications, menus, and settings.',
            ],
          },
          {
            title: 'Fixes',
            items: [
              'More reliable TikTok collection import, sync, and retry, including shared links and pagination.',
              'Smoother in-app TikTok playback, with next-video preloading and clearer access states.',
              'The X extension better handles posts without videos, suspended posts, and Discord links.',
            ],
          },
        ],
      },
      {
        version: '1.0.6',
        date: 'August 27, 2026',
        isoDate: '2026-08-27',
        sections: [{ title: 'New and fixed', items: ['Added the experimental Gobird X feed, which can be enabled in Advanced settings.', 'Improved Firefox signing and the Windows release workflow.'] }],
      },
      {
        version: '1.0.5',
        date: 'March 19, 2026',
        isoDate: '2026-03-19',
        sections: [{ title: 'Release', items: ['Released the Windows app and browser extensions.'] }],
      },
      {
        version: '1.0.4',
        date: 'February 15, 2026',
        isoDate: '2026-02-15',
        sections: [{ title: 'New', items: ['Added the Windows installer and core app structure, with French, English, and Arabic translations.'] }],
      },
      {
        version: '1.0.3',
        date: 'February 1, 2026',
        isoDate: '2026-02-01',
        sections: [{ title: 'New', items: ['Added link detection, video selection, and sending items to the download queue.'] }],
      },
      {
        version: '1.0.0',
        date: 'January 31, 2026',
        isoDate: '2026-01-31',
        sections: [{ title: 'First release', items: ['First Windows downloader, local WebSocket bridge, and Chrome and Firefox extensions.'] }],
      },
    ],
  },
  ar: {
    title: 'ملاحظات الإصدار',
    description: 'تعرّف على الميزات والتحسينات والإصلاحات في TapLoad.',
    eyebrow: 'TapLoad · Windows',
    heading: 'ما الذي تغيّر؟',
    intro: 'الميزات والتحسينات والإصلاحات المتوفرة في إصدارات TapLoad.',
    latest: 'أحدث إصدار',
    release: 'الإصدار',
    back: 'العودة إلى الرئيسية',
    browse: 'استكشف الإضافات',
    releases: [
      {
        version: '1.0.20',
        date: '25 سبتمبر 2026',
        isoDate: '2026-09-25',
        latest: true,
        sections: [{
          title: 'إصلاحات',
          items: [
            'تحديث yt-dlp لمواكبة التغييرات الأخيرة في استخراج فيديوهات TikTok.',
            'تمييز أفضل بين قيود الخصوصية في TikTok وحدود الشبكة واختبارات التحقق.',
            'إزالة الفيديوهات المؤكدة على أنها خاصة أو غير متاحة نهائياً من التنزيلات الفاشلة والأرشيفات.',
          ],
        }],
      },
      {
        version: '1.0.19',
        date: '25 سبتمبر 2026',
        isoDate: '2026-09-25',
        sections: [
          {
            title: 'جديد',
            items: [
              'خدمة Tor Expert Bundle اختيارية على Windows. تتوقف التنزيلات عبر Tor عند تعذّر اتصال SOCKS5.',
              'أضيف مشغّل عمودي داخل التطبيق وعرض أغلفة للمجموعات إلى أرشيف TikTok.',
              'قسم جديد لاستخدام مساحة التخزين يفحص المجلدات ويعرض مخططاً وتفاصيلها.',
            ],
          },
          {
            title: 'تحسينات',
            items: [
              'تبسيط أرشيف TikTok وتوضيح الإجراءات وإزالة عناصر التحكم غير المكتملة أو المكررة.',
              'إتاحة الإحصاءات من الشريط العائم والمنظّم الذكي من الشريط الجانبي.',
              'تحسين فرز الأحجام وتوسيع الترجمات للإشعارات والقوائم والإعدادات.',
            ],
          },
          {
            title: 'إصلاحات',
            items: [
              'تحسين استيراد مجموعات TikTok ومزامنتها وإعادة المحاولة، بما في ذلك الروابط المشتركة وتقسيم الصفحات.',
              'تشغيل أكثر سلاسة لفيديوهات TikTok داخل التطبيق مع تحميل الفيديو التالي مسبقاً وتوضيح حالات الوصول.',
              'تحسين إضافة X للتعامل مع المنشورات بلا فيديو أو المعلّقة وروابط Discord.',
            ],
          },
        ],
      },
      {
        version: '1.0.6',
        date: '27 أغسطس 2026',
        isoDate: '2026-08-27',
        sections: [{ title: 'جديد وإصلاحات', items: ['إضافة موجز X التجريبي Gobird ويمكن تفعيله من الإعدادات المتقدمة.', 'تحسين توقيع Firefox وسير عمل إصدار Windows.'] }],
      },
      {
        version: '1.0.5',
        date: '19 مارس 2026',
        isoDate: '2026-03-19',
        sections: [{ title: 'الإصدار', items: ['إصدار تطبيق Windows وإضافات المتصفح.'] }],
      },
      {
        version: '1.0.4',
        date: '15 فبراير 2026',
        isoDate: '2026-02-15',
        sections: [{ title: 'جديد', items: ['إضافة مثبت Windows والبنية الأساسية للتطبيق مع ترجمات الفرنسية والإنجليزية والعربية.'] }],
      },
      {
        version: '1.0.3',
        date: '1 فبراير 2026',
        isoDate: '2026-02-01',
        sections: [{ title: 'جديد', items: ['إضافة اكتشاف الروابط واختيار الفيديوهات وإرسالها إلى قائمة التنزيلات.'] }],
      },
      {
        version: '1.0.0',
        date: '31 يناير 2026',
        isoDate: '2026-01-31',
        sections: [{ title: 'الإصدار الأول', items: ['أول إصدار من أداة التنزيل على Windows وجسر WebSocket المحلي وإضافتي Chrome وFirefox.'] }],
      },
    ],
  },
} as const;
