# Site web Cross2Play

Landing page marketing (style sombre tech / blue–cyan–purple), **FR / EN**.

Éditeur : **NADAY LABS** (SAS) · contact@nadaylabs.com · hébergement AWS Amplify.

## Langues

Sélecteur **FR | EN** dans la barre de navigation (préférence mémorisée dans `localStorage`, défaut selon le navigateur).

## Lancer en local

```bash
cd website
python3 -m http.server 8080
# → http://localhost:8080
```

## Pages

| Chemin | Contenu |
|--------|---------|
| `index.html` | Landing |
| `legal/mentions-legales.html` | Mentions légales (LCEN) |
| `legal/confidentialite.html` | Politique de confidentialité (RGPD) |
| `legal/cgu.html` | Conditions générales d’utilisation |
| `legal/cookies.html` | Cookies / localStorage |

Textes : `js/i18n.js`. Liens produit : dépôt [NadayLabs/Cross2play](https://github.com/NadayLabs/Cross2play).

## Déploiement

- AWS Amplify / GitHub Pages / Cloudflare Pages / Netlify : root = `website`.
