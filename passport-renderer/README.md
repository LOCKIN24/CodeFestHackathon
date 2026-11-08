# Milk Passport renderer

Original local Three.js book and stamp implementation, adapted as a read-only renderer for the Flutter app. It retains cover/paper/stamp art, opening, page turns, stamp details, reduced motion and paper fallback. The current cover is upright with a centered serif title and lower emblem. Supplemental animation copy and emoji are removed.

## Build and test

From this directory:

```sh
npm ci
npm test
npm run build
```

The build writes a self-contained `../TownPass/assets/passport/passport.html` and the Three.js MIT license. Commit those generated runtime assets when renderer source changes. Node/Vite are build-time only; the installed app uses no network assets for the passport.

`window.milkPassportHost.setRecords(payload)` receives sanitized existing records. It never claims an allowance, stores browser progress or creates sample stamps. Its `suspend`, `resume` and `dispose` methods stop rendering and release resources; replay cannot add records. See [the host contract](PROVENANCE.md).
