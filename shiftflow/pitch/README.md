
## Contenuto

| File / cartella | Cosa contiene |
|---|---|
| [info-app.md](info-app.md) | Descrizione dell'app, funzionalità, architettura, numeri di qualità |
| [palette.md](palette.md) | Palette colori del brand (con codici hex) e tipografia |
| [loghi/](loghi/) | Logo e icone dell'app in PNG (varianti chiara, scura, monocromatica) |
| [font/](font/) | Il font del brand (Manrope, variabile) da installare per le slide |

## Loghi disponibili

| File | Uso consigliato |
|---|---|
| `loghi/app_icon.png` | Icona dell'app completa (1024×1024, con sfondo) — copertina slide |
| `loghi/app_icon_bg.png` | Solo lo sfondo a gradiente dell'icona |
| `loghi/app_icon_foreground.png` | Solo l'onda "S", trasparente — da sovrapporre a sfondi propri |
| `loghi/app_icon_monochrome.png` | Silhouette a un colore — filigrane, timbri, stampe in b/n |
| `loghi/splash_logo.png` | Logo per sfondi chiari |
| `loghi/splash_logo_dark.png` | Logo per sfondi scuri |

Il logo è disegnato via codice ([lib/core/branding/shiftflow_logo.dart](../lib/core/branding/shiftflow_logo.dart)):
se serve una risoluzione diversa si può ri-esportare con lo strumento in
`test/tools/` senza perdita di qualità.
