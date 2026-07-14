# Palette e tipografia di ShiftFlow

Fonte nel codice: [lib/core/theme/app_colors.dart](../lib/core/theme/app_colors.dart)
e [lib/core/theme/app_status_colors.dart](../lib/core/theme/app_status_colors.dart).

## Colore del brand

Il colore "seme" di tutta l'app è lo **smeraldo 600 `#059669`**.
Il gradiente del logo va da smeraldo 300 → 600 → 900 (alto-sinistra → basso-destra).

## Scala smeraldo

| Nome | Hex | Uso tipico |
|---|---|---|
| Emerald 950 | `#022C22` | Inizio sfondo dark mode |
| Emerald 900 | `#064E3B` | Estremo scuro del gradiente logo |
| Emerald 800 | `#065F46` | Testi su container verdi (light) |
| Emerald 700 | `#047857` | "Eco" inferiore del logo, successo (light) |
| **Emerald 600** | **`#059669`** | **Colore seme del tema (brand)** |
| Emerald 400 | `#34D399` | Successo in dark mode |
| Emerald 300 | `#6EE7B7` | "Eco" superiore del logo |
| Emerald 200 | `#A7F3D0` | Testi chiari su container scuri |
| Emerald 100 | `#D1FAE1` | Container successo (light) |
| Mint 50 | `#ECFDF5` | Inizio sfondo light mode |

## Sfondi e superfici

| Nome | Hex | Uso |
|---|---|---|
| Gradiente light | `#ECFDF5` → `#FFFFFF` | Sfondo ambientale (light) |
| Gradiente dark | `#022C22` → `#0B1210` | Sfondo ambientale (dark) |
| Dark surface | `#101413` | Superfici in dark mode |
| Glass light | `#FFFFFF` (traslucido) | Card "vetro" in light mode |
| Glass dark | `#1A2420` (traslucido) | Card "vetro" in dark mode |

## Colori semantici di stato

Tutte le coppie container/testo rispettano un contrasto ≥ 4.5:1 (WCAG AA).

| Stato | Light | Container light | Dark | Container dark |
|---|---|---|---|---|
| Successo / approvata | `#047857` | `#D1FAE1` | `#34D399` | `#064E3B` |
| Attenzione / in attesa | `#B45309` | `#FEF3C7` | `#FBBF24` | `#78350F` |
| Errore / rifiutata | `#B91C1C` | `#FEE2E2` | `#F87171` | `#7F1D1D` |
| Informazione | `#1D4ED8` | `#DBEAFE` | `#60A5FA` | `#1E3A8A` |

Convenzione del design system: **ferie** usano il colore info (blu),
**permesso** il warning (ambra), così i due tipi si distinguono a colpo d'occhio.

## Tipografia

- Font unico: **Manrope** (variabile, incluso in [font/](font/)).
- Titoli in **ExtraBold (800)** / Bold (700), etichette in SemiBold (600),
  corpo del testo in peso regolare.
- Scala tipografica: quella standard Material 3, con Manrope applicato sopra.
