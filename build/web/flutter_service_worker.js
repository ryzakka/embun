'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "892c04aeff2583d56b6842341c3eac03",
"assets/AssetManifest.bin.json": "ca057ab95bad432246f58e9894ca00f1",
"assets/assets/bentang/desajembatan-kering.webp": "867d4e8dfd360f30f67d6100fc199d9f",
"assets/assets/bentang/desajembatan-keringgulita.webp": "1837c9efac64ae6e27e37c42484f3148",
"assets/assets/bentang/lembah-hijau0.webp": "01bc0854745fd8265063d4e38cf5dc80",
"assets/assets/bentang/lembah-hijau1.webp": "ce1e854a2a3e22f58e59d2321aee7a8e",
"assets/assets/bentang/lembah-hijau2.webp": "bcdec857c2a94e8a4b311306b00786de",
"assets/assets/bentang/lembah-hijau3.webp": "9723619de85094a101cabbe0b7c55f98",
"assets/assets/bentang/lembah-hijau4.webp": "5ebdcf63840142bf4af5eafd187d993a",
"assets/assets/bentang/lembah-hijau5.webp": "9fea54870f1270847218e7b67896a9d5",
"assets/assets/bentang/pohon-zoom.webp": "2fd7b4b702bad09165522c186f3ac4a9",
"assets/assets/bentang/rumahdesa-gersang.webp": "25e01c63ab0de2503256006a11a88c8e",
"assets/assets/bentang/rumahdesa-hijau.webp": "7123a012b194dffd0539de4de97a40fc",
"assets/assets/kartu/antagonis/kegelapan1.webp": "8315e69a2e0b945bc3e6713ec20bde37",
"assets/assets/kartu/antagonis/kegelapan10.webp": "f4f3059f1b7415c815e0f32b46766a28",
"assets/assets/kartu/antagonis/kegelapan11.webp": "74fa4c835499f16cd268c555bbd620f7",
"assets/assets/kartu/antagonis/kegelapan12.webp": "c6ff1af0d6ed9c915adaea32ce0fc34d",
"assets/assets/kartu/antagonis/kegelapan13.webp": "8929fb4a935513255f26e7c00c89b4d8",
"assets/assets/kartu/antagonis/kegelapan14.webp": "802b11b99d621092b4c079ee7bb927f9",
"assets/assets/kartu/antagonis/kegelapan15.webp": "a8d0a12a0bf71200a8045b1e4fd0c8d6",
"assets/assets/kartu/antagonis/kegelapan16.webp": "7192a2edd3f59854c31e35ed781e8013",
"assets/assets/kartu/antagonis/kegelapan17.webp": "2bdd6feb59ca381fa56730f1a52e3533",
"assets/assets/kartu/antagonis/kegelapan18.webp": "870c31cf71f89e588e9a9cd275e225e0",
"assets/assets/kartu/antagonis/kegelapan19.webp": "301a83e9812b40bea76ffb97f11a7869",
"assets/assets/kartu/antagonis/kegelapan2.webp": "9f3c4c83d7b91b9eb5c42c202aefc9a6",
"assets/assets/kartu/antagonis/kegelapan20.webp": "b1287c3c60fb1f8338dc6808a11dd6ec",
"assets/assets/kartu/antagonis/kegelapan21.webp": "a889c5c8f2c49db2a85ed8daeaa13af1",
"assets/assets/kartu/antagonis/kegelapan22.webp": "528dfca077db124f17006fcbec0aae1f",
"assets/assets/kartu/antagonis/kegelapan23.webp": "c8b22eea982b1859cc75141464cdcb9b",
"assets/assets/kartu/antagonis/kegelapan24.webp": "0fc26e0eb3fb242e41ee453431d391e7",
"assets/assets/kartu/antagonis/kegelapan25.webp": "45a8a5707a0d74a3ca4ba0262569661d",
"assets/assets/kartu/antagonis/kegelapan3.webp": "e87c0cf0d540ea6009fb0a690030fe28",
"assets/assets/kartu/antagonis/kegelapan4.webp": "050d8732f17a0a6ea51a7dc089da5f5a",
"assets/assets/kartu/antagonis/kegelapan5.webp": "adaeeb0daa930adc1f353af502c98e99",
"assets/assets/kartu/antagonis/kegelapan6.webp": "232b7b6806ef71ab5ec0de78ba39d061",
"assets/assets/kartu/antagonis/kegelapan7.webp": "4f4bb3b53e78dfba7cbaa1d0011d5f5b",
"assets/assets/kartu/antagonis/kegelapan8.webp": "2ee4d9f7672c56ef5397dc735c3c80ff",
"assets/assets/kartu/antagonis/kegelapan9.webp": "8365d15fb554e22482544c972a29ca03",
"assets/assets/kartu/protagonis/atlet1.webp": "abaa67890e95e9309c55d7b705aae151",
"assets/assets/kartu/protagonis/atlet2.webp": "30baf7518dff27259def827c8102e600",
"assets/assets/kartu/protagonis/atlet3.webp": "e4cab76764fb0d6f541fe19d748d8735",
"assets/assets/kartu/protagonis/atlet4.webp": "2cbd570fff407f502f0500d20a5e9edb",
"assets/assets/kartu/protagonis/atlet5.webp": "1bbbcc981b18effb7628e3b92b6eafd2",
"assets/assets/kartu/protagonis/atlet6.webp": "83f05d1f298c564104c2e67dfe233e50",
"assets/assets/kartu/protagonis/besi1.webp": "2c65900d9bd9398ad4df5e838ef679b8",
"assets/assets/kartu/protagonis/guru1.webp": "72275283537c4cbb89722e6802a37eac",
"assets/assets/kartu/protagonis/masak1.webp": "93fc816980aa9be4f62419dc572cdd55",
"assets/assets/kartu/protagonis/montir1.webp": "ec1cac4ba126cbd43ab7431daf9fb862",
"assets/assets/kartu/protagonis/nelayan1.webp": "ccd230e83b47efe243f21444cec0529b",
"assets/assets/kartu/protagonis/nelayan2.webp": "fdb2cdcfb0e053efce11de1aa9d7a0af",
"assets/assets/kartu/protagonis/nelayan3.webp": "1358a593808c0baf5e4169a068a4d151",
"assets/assets/kartu/protagonis/pekebun1.webp": "70cd77387d3eab026969b0967e48c8e5",
"assets/assets/kartu/protagonis/pekerja1.webp": "149e6756037cd4fbdea531c8b0dceae8",
"assets/assets/kartu/protagonis/pekerja2.webp": "4a9fa6ec7059c59fdee994dac4831bc6",
"assets/assets/kartu/protagonis/pekerja3.webp": "912fabe5b79ca5ff6c3937633c9bdf7b",
"assets/assets/kartu/protagonis/pekerja4.webp": "47e17701e794bef5de58d4245fa6f9cf",
"assets/assets/kartu/protagonis/pekerja5.webp": "498610c5d06368b5904bf9f0b4ab8d7c",
"assets/assets/kartu/protagonis/pemadam1.webp": "9292c1fa47b234bb0050bf905ca9f6b0",
"assets/assets/kartu/protagonis/perajut1.webp": "5e754b80c803a0e5cd0514b13f21a6da",
"assets/assets/kartu/protagonis/peramu1.webp": "b6096ea3744672df42665e0c15ced2af",
"assets/assets/kartu/protagonis/perawat1.webp": "a23773ff64ada4df9dc9d0a31f3ce90e",
"assets/assets/kartu/protagonis/petani1.webp": "df201ea1027804d32b97294cd0027573",
"assets/assets/kartu/protagonis/petani2.webp": "d5271239f3641fdff4e63bb81e34349c",
"assets/assets/kartu/protagonis/petua1.webp": "3dc9d8b0dc1ada5fd8933a24069087d1",
"assets/assets/kartu/protagonis/pianis1.webp": "958d0f89e16b3130727d1f54fecb1f27",
"assets/assets/kartu/protagonis/polisi1.webp": "ad9c102e33675da3973daba0fe7a3b54",
"assets/assets/kartu/protagonis/pustakawan1.webp": "37557757dd18eb1f86d670f5793798a4",
"assets/assets/kartu/protagonis/pustakawan2.webp": "a22f07708d3c3e0a6de7359497f76a27",
"assets/assets/kartu/protagonis/warga1.webp": "c46b90591c27f51e9fbc918706a4ee0b",
"assets/assets/kartu/protagonis/warga10.webp": "bbfd2cf1c4b361cafeba99cc4c212402",
"assets/assets/kartu/protagonis/warga11.webp": "5a1c2f01063a9db619802c396c3d3334",
"assets/assets/kartu/protagonis/warga12.webp": "5394deda5ec8daeefaf651205adb753c",
"assets/assets/kartu/protagonis/warga13.webp": "feed52600bf84b3210f3785955f845d3",
"assets/assets/kartu/protagonis/warga14.webp": "f17199adc9873aa5897b4383e51ede97",
"assets/assets/kartu/protagonis/warga15.webp": "408b26928e29324303051cbde8ee2b4d",
"assets/assets/kartu/protagonis/warga16.webp": "fdc7f9b09cd1750dc035d9cae7820d8d",
"assets/assets/kartu/protagonis/warga17.webp": "5bb8f388eabd2c079f9e566c8b09af86",
"assets/assets/kartu/protagonis/warga18.webp": "10fabe3d3d5a82609787992844ecf483",
"assets/assets/kartu/protagonis/warga2.webp": "bd01286709e3b76202246763f2197fba",
"assets/assets/kartu/protagonis/warga3.webp": "eb4a058f82c8cbbdec054408ab0c32e8",
"assets/assets/kartu/protagonis/warga4.webp": "7c8ddc5343347a39210ff524126d4c5f",
"assets/assets/kartu/protagonis/warga5.webp": "64aaad1d82a3beb7b9ea6143d078ef74",
"assets/assets/kartu/protagonis/warga6.webp": "67d55086ea15df013ad54ee6ec8f0508",
"assets/assets/kartu/protagonis/warga7.webp": "20cfbcf539a4ac31d82e6586f44c87bb",
"assets/assets/kartu/protagonis/warga8.webp": "d31528ae956b2bc5f533b32744989d3b",
"assets/assets/kartu/protagonis/warga9.webp": "f9f69f0d82c2253f926e1b6634a5225c",
"assets/assets/pohon/pohon0-sakura.webp": "b3fed012e7b6b106f47d6facf2f9240b",
"assets/assets/pohon/pohon0.webp": "b5e519b94b0697601945c4868d9278c0",
"assets/assets/pohon/pohon1.webp": "6df79fd7be8f04befa3b6b91b9644a21",
"assets/assets/pohon/pohon2.webp": "2255490b3ac9fc0d1a9d397b4918cf5a",
"assets/assets/pohon/pohon3.webp": "18d23bd5207c3003ef0dd7a64b9d76e4",
"assets/assets/pohon/pohon4.webp": "74a1d40ed3a5443d87bdab59a163aee9",
"assets/assets/pohon/pohon5.webp": "2692bcb7d1b40bbabef5dc3f1bb0eeb0",
"assets/assets/pohon/pohon6.webp": "325092b2bfc31cdb08b96b7c7da8b370",
"assets/assets/pohon/pohon7.webp": "c5f523007df07bbf2cade5fb82abe55d",
"assets/assets/pohon/pohon8.webp": "63e33815dc15a112d489e5733ee7c632",
"assets/assets/pohon/pohon9.webp": "01455e4b8df0348610e57631081d21b3",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "4a6bc8d9f8aa049b4bd7840986f47604",
"assets/NOTICES": "bacb8c5290b7c29123ff28e1114e5055",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "e8bf02b6bbd41b02a9f3aa8c13bd9e9c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "de5cd924341a6010f14615fdbbbc0952",
"/": "de5cd924341a6010f14615fdbbbc0952",
"main.dart.js": "c273b044d1aefad2e7c505a9519e4503",
"manifest.json": "df5ecdba13a1656c0809325677030ab9",
"version.json": "5f7aaaa3c3b9afbeb1df6ee4593452d9"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
