# Muslim 5 site

Astro and Tailwind CSS landing and privacy pages for Muslim 5, deployed as Cloudflare Workers Static Assets. Bun is the package manager and script runner.

## Local development

```sh
bun install
bun run dev
```

## Verify and deploy

```sh
bun run check
bun run deploy
```

The deployed routes are:

- `/` for the landing page
- `/privacy/` for the privacy policy and privacy choices

The App Store listing can use `/privacy/` as both the Privacy Policy URL and the optional User Privacy Choices URL with `#your-choices` appended.
