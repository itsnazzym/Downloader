import { useState, type CSSProperties } from 'react';
import { XIcon } from 'lucide-react';
import { Button } from './ui/button';
import {
  Sheet, SheetClose, SheetContent, SheetDescription, SheetHeader, SheetTitle, SheetTrigger,
} from './ui/sheet';

type Link = { label: string; href: string; current?: boolean };
type LanguageLink = { label: string; href: string; code: string; current?: boolean };

type Props = {
  lang: 'fr' | 'en' | 'ar';
  variant?: 'site' | 'library';
  menuLabel: string;
  navigationLabel: string;
  downloadLabel: string;
  links: Link[];
  languages: LanguageLink[];
};

export default function MobileNavigation({
  lang, variant = 'site', menuLabel, navigationLabel, downloadLabel,
  links, languages,
}: Props) {
  const [open, setOpen] = useState(false);
  const closeLabel = lang === 'fr' ? 'Fermer le menu' : lang === 'ar' ? 'إغلاق القائمة' : 'Close menu';

  return (
    <div className={variant === 'library' ? 'library-mobile-menu' : 'mobile-menu'}>
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetTrigger asChild>
          <Button type="button" variant="outline" className="mobile-menu-trigger" aria-label={menuLabel}>
            <span className="menu-icon" aria-hidden="true" />
            {menuLabel}
          </Button>
        </SheetTrigger>
        <SheetContent
          side={lang === 'ar' ? 'left' : 'right'}
          showCloseButton={false}
          className="site-mobile-sheet"
          dir={lang === 'ar' ? 'rtl' : 'ltr'}
        >
          <SheetHeader className="site-mobile-sheet-header">
            <SheetTitle>{navigationLabel}</SheetTitle>
            <SheetDescription className="sr-only">{navigationLabel}</SheetDescription>
            <SheetClose asChild>
              <Button type="button" variant="ghost" className="site-mobile-sheet-close" aria-label={closeLabel}><XIcon aria-hidden="true" /></Button>
            </SheetClose>
          </SheetHeader>
          <nav className="site-mobile-sheet-links" aria-label={navigationLabel}>
            {links.map((link, index) => (
              <SheetClose asChild key={link.href + link.label}>
                <a href={link.href} aria-current={link.current ? 'page' : undefined} style={{ '--item-index': index } as CSSProperties}>
                  <span>{link.label}</span><span aria-hidden="true">↗</span>
                </a>
              </SheetClose>
            ))}
          </nav>
          <div className="site-mobile-sheet-bottom">
            <nav className="site-mobile-languages" aria-label={lang === 'fr' ? 'Langue' : lang === 'ar' ? 'اللغة' : 'Language'}>
              {languages.map((language) => (
                <SheetClose asChild key={language.code}>
                  <a href={language.href} lang={language.code} aria-current={language.current ? 'page' : undefined}>{language.label}</a>
                </SheetClose>
              ))}
            </nav>
            <SheetClose asChild>
              <button type="button" className="site-mobile-download" data-download-open aria-haspopup="dialog">
                {downloadLabel}<span aria-hidden="true">↓</span>
              </button>
            </SheetClose>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
