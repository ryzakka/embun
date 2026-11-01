'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "0d19bb1189597bb45149d4b6d1d71d98",
"assets/AssetManifest.bin.json": "55874c52f29e367f0b240f0b7da57fca",
"assets/assets/bentang/alunalun-tiangberpita.webp": "250ce118405c1d83668adf39ad9a40ff",
"assets/assets/bentang/balaidesa-dalamsiang.webp": "d50b9aad29b97e0f14dd847e777fade9",
"assets/assets/bentang/balaidesa-luarsiang.webp": "50e73983aec67143f0b9ac609b7a45ee",
"assets/assets/bentang/desajembatan-kering.webp": "3dff3ab0c7348bd2d8b30043e205146d",
"assets/assets/bentang/desajembatan-keringgulita.webp": "5ff23b12066b69e4e292c987677949c6",
"assets/assets/bentang/gerobakdankeranjang.webp": "a5ec1806db6a89dcb2774658a15c00c5",
"assets/assets/bentang/kamarkayudesa.webp": "d8ab9b1fd6497f2e33870a051561f473",
"assets/assets/bentang/keterasingan.webp": "bc50f5c5ca5777d75a18c59888b7eedc",
"assets/assets/bentang/ladang-gersang.webp": "56d130cc8d16ee581b37049c57e65d69",
"assets/assets/bentang/langit-fajar.webp": "72c484c1d954de5a66274c3b2ede139d",
"assets/assets/bentang/langit-malamberawan.webp": "c78aa29161b8294b1ee079a7f53cd09c",
"assets/assets/bentang/langit-malammerahungugelap.webp": "317e8250f4f1bab1b36d1dc8df443b66",
"assets/assets/bentang/langit-matamerahgelap.webp": "de297545d82b475ea57b44f9f7af802b",
"assets/assets/bentang/lembah-hijau0.webp": "5768e8b2ac68634d9b0e3c69f99f77ff",
"assets/assets/bentang/lembah-hijau1.webp": "a765f6112b6a600694428949190fa98c",
"assets/assets/bentang/lembah-hijau2.webp": "a82cdd6b2bf08c7a2bb7d71caf6599ef",
"assets/assets/bentang/lembah-hijau3.webp": "fec67c3bacf5adfa9dc37e345e1d7cf7",
"assets/assets/bentang/lembah-hijau4.webp": "c3f904f7135d919d510fe10b0236237b",
"assets/assets/bentang/lembah-hijau5.webp": "508a760980327cd5d3a29d0322baf312",
"assets/assets/bentang/lembah-malamindah.webp": "e27fed3128eb217340200b7f531a8c63",
"assets/assets/bentang/lembah-malamkering.webp": "432af36eb5dc1887aa53ded081e7ed10",
"assets/assets/bentang/menaralonceng-sianghari.webp": "228d9ce03cba55898f5afa216847a5d5",
"assets/assets/bentang/pasar-sianghari.webp": "035015d998144f95bdbeb20da04ba201",
"assets/assets/bentang/perpustakaantua.webp": "b02ee8c873ad49f39cfcf2647af239f7",
"assets/assets/bentang/peternakan-sianghari.webp": "7d656476e9f503a4ce28725447ede0fc",
"assets/assets/bentang/pohon-keranjangbuah.webp": "98be8412b94f6e64a88f8922442bc2c0",
"assets/assets/bentang/pohon-toplesnyaladankunang.webp": "74657cb9c3497761fabc35681216547a",
"assets/assets/bentang/pohon-zoom.webp": "9954702e6db7c6c44ba557224fcd2425",
"assets/assets/bentang/pohon-zoomberkascahayanaik.webp": "e34e74f69a54e6ac134efb55b0c95dd3",
"assets/assets/bentang/rumah-malamdepanpintu.webp": "4d7c1c57f7fe2eea130f0bcfb5c678e8",
"assets/assets/bentang/rumahdesa-gersang.webp": "8007db6b889be43e59fc710e0896d7c2",
"assets/assets/bentang/rumahdesa-hijau.webp": "a003b0422fcc0b54c5be25017ee62c95",
"assets/assets/bentang/rumahdesa2-gersang.webp": "2b3ea72d5f231df82c48e7a1a57fc36b",
"assets/assets/bentang/sinarmataharikedalamrumah.webp": "8a6d34a824a02a69d2bdfc8016ca2185",
"assets/assets/bentang/sumur-gelapmalam.webp": "4ed12077df9099254b5df5ab1f3485f4",
"assets/assets/bentang/sumur-sianghari.webp": "203f2e7123019205c569f77ff67dd84d",
"assets/assets/bentang/tepisungai-tanggaterjalsianghari.webp": "cf870b7aa97e27b7aa0f7fa460f738b3",
"assets/assets/bentang/tertunjuk.webp": "dff6999ee22cb9923a817698cb44f339",
"assets/assets/ikon/alert.webp": "5f3d41902945bed7bb5ebad5d0bf9b08",
"assets/assets/ikon/announcement.webp": "12c8cbdc9074c38accc50954cfe28d2d",
"assets/assets/ikon/back.webp": "83526019a94019213207683c8a066568",
"assets/assets/ikon/barter.webp": "1d051c9fea91e39b22c0de24039ebcd6",
"assets/assets/ikon/bubarkan.webp": "11b952e2bcb1a589f201dba95dc6c928",
"assets/assets/ikon/bulirembun.webp": "5b714708354e39b8db7ab29d0dd97923",
"assets/assets/ikon/bulirhitam.webp": "80e398cce2cb252d3b205a21cae04ff8",
"assets/assets/ikon/centang.webp": "86b1976f89af8a5dfa7525cae9bf8295",
"assets/assets/ikon/change.webp": "0aed6299094de29de14c4a55efea6ef1",
"assets/assets/ikon/character.webp": "6390f45a2b05bd191cad8db3cbb31861",
"assets/assets/ikon/customization.webp": "3be8745eb471711452972e8591f7076b",
"assets/assets/ikon/danger.webp": "5f3d41902945bed7bb5ebad5d0bf9b08",
"assets/assets/ikon/dibeli.webp": "addbc0125690c757d334f9d799bc2ee1",
"assets/assets/ikon/dipilih.webp": "9a54d6a35c7d978c19c86d99e41b2571",
"assets/assets/ikon/discuss.webp": "2339419d33da255d155aacc7b65f300e",
"assets/assets/ikon/donations.webp": "4ad30a492fe39428e9ca2f637166e577",
"assets/assets/ikon/endday.webp": "02e47e820bbc65deca14590f65e5133f",
"assets/assets/ikon/hari.webp": "d4d3a1a0fa1ffc704f735df48b52c25e",
"assets/assets/ikon/helaidaun.webp": "0db5d264933d59178a59af6d99cb15f4",
"assets/assets/ikon/hide.webp": "0fce357ce869feafc6c7da33b6b3acee",
"assets/assets/ikon/home.webp": "eface37b143505da03cef442a9b68fc6",
"assets/assets/ikon/host.webp": "ba96ffdf8f876c08aff83c7490dcd0bc",
"assets/assets/ikon/identity.webp": "1474d3c004efb408d79598144c03272b",
"assets/assets/ikon/info.webp": "c7cd11fb1fbf6eabe3f8422fbfc49a94",
"assets/assets/ikon/item.webp": "df7f0c8e8b1cfa3552a870f9c2cd0b45",
"assets/assets/ikon/joinroom.webp": "3c53844b574f8d18e3a6f19ffc5a8db0",
"assets/assets/ikon/keluar.webp": "f603e8ddcd61581d01d72560d6b071a9",
"assets/assets/ikon/kirim.webp": "b76726c92c5ad7f193412bc9e9f59d51",
"assets/assets/ikon/lock.webp": "1f8d0c3437198c31fd25c1e4928b5ddb",
"assets/assets/ikon/logorhistory.webp": "3aa3aced314228f94b71b7af0ea765b9",
"assets/assets/ikon/menu.webp": "53b1eb380e4e80dbe48701739f5ff14b",
"assets/assets/ikon/minus.webp": "318360dd83fbb4d1b94f136cfb9d0114",
"assets/assets/ikon/mydeck.webp": "fc4ed23279cc25880220363f1cb0f364",
"assets/assets/ikon/mydeck2.webp": "f0cfd8913005efd5d1f0f76a78aa3cbc",
"assets/assets/ikon/persona.webp": "c3d9ba4632b8fdb87c6e519d2b80c2c8",
"assets/assets/ikon/plus.webp": "f556ebd6e47639d040f9bfab61fdbeb8",
"assets/assets/ikon/poinmin1.webp": "d149a81efcc2ae28be88acfd8f454cf7",
"assets/assets/ikon/poinplus1.webp": "a06e4a6e6bd6d004ac91863e38d0861a",
"assets/assets/ikon/question.webp": "d33024eea2cf7300209296d13590d5f5",
"assets/assets/ikon/refresh.webp": "0aed6299094de29de14c4a55efea6ef1",
"assets/assets/ikon/roomcode.webp": "bd1b027afbaf49a454b317f922efd5cf",
"assets/assets/ikon/roomcreate.webp": "eface37b143505da03cef442a9b68fc6",
"assets/assets/ikon/salin.webp": "1d6be2c5fb88c30ede309d5eecb0b4fc",
"assets/assets/ikon/settings.webp": "3be8745eb471711452972e8591f7076b",
"assets/assets/ikon/show.webp": "80284a7231e23d1bff0b4e5ed681a5bb",
"assets/assets/ikon/showaddgraphic.webp": "2f5fc7ae38d94d5a1191aedfa9d718df",
"assets/assets/ikon/silang.webp": "9d732002f3d7cb585f303585320e3ed5",
"assets/assets/ikon/simpan.webp": "15103df76f739c7168d47aa97220329f",
"assets/assets/ikon/skip.webp": "e9a56731cf4d51cc96f1a1d0f69539d2",
"assets/assets/ikon/skip2.webp": "d0d44a4de7e685481920a1ad1b93f8ee",
"assets/assets/ikon/start.webp": "18fa8899125f6e34cfb45202bb96f07e",
"assets/assets/ikon/store.webp": "72362fff24c713e26459db62d80c0a03",
"assets/assets/ikon/tertuduh.webp": "e46d084a9e7f6fbc73b434a5fcfc05b3",
"assets/assets/ikon/timer.webp": "7329ffb9206d3e2271ec78b768da14b2",
"assets/assets/ikon/titlepersembahan.webp": "067b154618b771b2fe9c6c5274245aa4",
"assets/assets/ikon/touch.webp": "6ce62a0a5b9848873d7a19ff4d24df8b",
"assets/assets/ikon/vote.webp": "592362b14cd47658a01608b9f7b9a2c2",
"assets/assets/ikon/wait.webp": "525a62f384331c414f302839f17f963f",
"assets/assets/ikon/x.webp": "802bfc05aa6e47824f70207bd023b9a4",
"assets/assets/kartu/antagonis/kegelapan1.webp": "4dba1fe2d393d2979376dd7b7189f36a",
"assets/assets/kartu/antagonis/kegelapan10.webp": "8ea9bd7f195d58726da5f0436be7cff7",
"assets/assets/kartu/antagonis/kegelapan11.webp": "528b6593190e952cc82f09318e0d41ee",
"assets/assets/kartu/antagonis/kegelapan12.webp": "4c3087db72c5a688a59d960677feb2e3",
"assets/assets/kartu/antagonis/kegelapan13.webp": "73cee4a68d7778e33408a3228b31f002",
"assets/assets/kartu/antagonis/kegelapan14.webp": "316ceca67a9cef77bfce1aa625f1e7c6",
"assets/assets/kartu/antagonis/kegelapan15.webp": "bd59fce5c2c31c02059c813a3527cb34",
"assets/assets/kartu/antagonis/kegelapan16.webp": "acb33e8b69281164cd1edad518003ca9",
"assets/assets/kartu/antagonis/kegelapan17.webp": "71f2b090818f7631d7b3fb707e8a1f8f",
"assets/assets/kartu/antagonis/kegelapan18.webp": "0cea6964a767d80bedcca0cda6e329bc",
"assets/assets/kartu/antagonis/kegelapan19.webp": "a4f49aa163dee127b0a1aa37d0fbdaea",
"assets/assets/kartu/antagonis/kegelapan2.webp": "002e032d0703c66ba890ef9c5788b04e",
"assets/assets/kartu/antagonis/kegelapan20.webp": "0f72e807802367c95c5256efc2bade80",
"assets/assets/kartu/antagonis/kegelapan21.png": "169a098efbc729c70cc5ca78978923e4",
"assets/assets/kartu/antagonis/kegelapan22.png": "f1576424d620aa8a30d24d0e88d5163f",
"assets/assets/kartu/antagonis/kegelapan23.png": "dbd98716a116f978197a5d5df9a29a17",
"assets/assets/kartu/antagonis/kegelapan24.png": "9ec9fd77331a18a105b6d39a7b0b2e96",
"assets/assets/kartu/antagonis/kegelapan3.webp": "5255e0d56187bd9baa84f4e9481f93d8",
"assets/assets/kartu/antagonis/kegelapan4.webp": "0b0c49790dadbe938970bac8b333d8d1",
"assets/assets/kartu/antagonis/kegelapan5.webp": "a013059a4890105cff3f287368e3e532",
"assets/assets/kartu/antagonis/kegelapan6.webp": "932220569ae9eae51f664551accdb753",
"assets/assets/kartu/antagonis/kegelapan7.webp": "a67ac6051e3ae331dfe9808dc6ffa7c9",
"assets/assets/kartu/antagonis/kegelapan8.webp": "da3e837f0c2af59972dfa0ea5c36d4ec",
"assets/assets/kartu/antagonis/kegelapan9.webp": "9918cb1909f870a4da7d6200c89965ac",
"assets/assets/kartu/kemampuan/kemampuan1.png": "fbed151f00e1085d8b52cd2e18293068",
"assets/assets/kartu/kemampuan/kemampuan10.png": "9184205e8d9de0b9dfcfddb225007dd8",
"assets/assets/kartu/kemampuan/kemampuan11.png": "351c8554ed4288a2cf7548b578f7ca29",
"assets/assets/kartu/kemampuan/kemampuan12.png": "420945bc176204c91c20e20f75f61822",
"assets/assets/kartu/kemampuan/kemampuan2.png": "581bb4c82ed9254c201bec0732eff8b6",
"assets/assets/kartu/kemampuan/kemampuan3.png": "59b64f07305f0098da46fb089acec6ce",
"assets/assets/kartu/kemampuan/kemampuan4.png": "acbadb63244c3ccbf1c82c47dc349c02",
"assets/assets/kartu/kemampuan/kemampuan5.png": "c4aa041363942600b13a402ecca6d40c",
"assets/assets/kartu/kemampuan/kemampuan6.png": "7f209c84a480f62a7178e7d639a7d60d",
"assets/assets/kartu/kemampuan/kemampuan7.png": "fa1304db475f3055884e355a8dbec918",
"assets/assets/kartu/kemampuan/kemampuan8.png": "f2d19d02181860841cea476ebdb3afa8",
"assets/assets/kartu/kemampuan/kemampuan9.png": "2ed8bda57223f3f4f14fcf17c6aadfd3",
"assets/assets/kartu/poweranta/asam-jerigen.png": "74904b193aea905b04d5acce49325848",
"assets/assets/kartu/poweranta/bisikan.png": "154c2916c767dfae1c2e8805f4b7373b",
"assets/assets/kartu/poweranta/boneka-sawah.png": "732dd19205eff937ee791de455470ce3",
"assets/assets/kartu/poweranta/boneka-voodoo.png": "c3d595512208cd1c70e3e85a4eef9c3e",
"assets/assets/kartu/poweranta/bulirhitam-drum.png": "3fdf9ebedfcdd950f8030acebe868b24",
"assets/assets/kartu/poweranta/bulirhitam-ember.png": "26869b1e3cc933e08bb3f55d36d5b9bd",
"assets/assets/kartu/poweranta/bulirhitam-emberbesar.png": "8f1b117c9699c6d825fb6c41e149e463",
"assets/assets/kartu/poweranta/bulirhitam-gelas.png": "86ea607e07a6a74441dddd8a8f5077bc",
"assets/assets/kartu/poweranta/cangkul.png": "563d25f41086f1987003b4e94b680aec",
"assets/assets/kartu/poweranta/gergaji-manual.png": "78d8598ba9f6d643530369ccf35553c3",
"assets/assets/kartu/poweranta/gergaji-mesin.png": "96c05d42f20f01f497fb3dc653d31fe9",
"assets/assets/kartu/poweranta/jahit-keranjangjahit.png": "785c3f1390c96c6423c90929317a464b",
"assets/assets/kartu/poweranta/kapak.png": "da4eaabd13b2d7599a3949f970ca6f59",
"assets/assets/kartu/poweranta/kawatberduri.png": "b4b73b4f4e253433fb8c2f75653856b9",
"assets/assets/kartu/poweranta/kontaminasi-kain.png": "f5f7d68ce1575ab5bdda2d6551ebf53a",
"assets/assets/kartu/poweranta/pengguntingrumput-mesin.png": "21d630b128a5f1e322f3fe623198cb34",
"assets/assets/kartu/poweranta/pupukpalsu-karung.png": "84d8ca78702284b220cb467aa4642cf1",
"assets/assets/kartu/poweranta/pupukpalsu-karungganda.png": "9fde8ba04eada2a8e8e5b40fe7ac2143",
"assets/assets/kartu/poweranta/racun-drum.png": "7ba890266ca0a6f09c3f8a05ce72d412",
"assets/assets/kartu/poweranta/racun-ember.png": "1d63a7ce8d5f1fc02f1216cf889aa0ee",
"assets/assets/kartu/poweranta/racun-sekop.png": "e37c6eca68c3e276643c5f85826f34f4",
"assets/assets/kartu/poweranta/racun-semprotan.png": "000ec32239337160e7e3c978ec329e0d",
"assets/assets/kartu/poweranta/racun-sudip.png": "5d69d197574b3f16e60c374b0ea215f0",
"assets/assets/kartu/poweranta/racun-suntik.png": "c21501de4b1ef25a8509b66a898e208d",
"assets/assets/kartu/poweranta/ramuan-hitampeningkatan.png": "ba3e73e3da674ba2343d8c70a5a5fd31",
"assets/assets/kartu/poweranta/ramuan-ungumistispercepatan.png": "34cb364e5a0038c247425e223cd74d32",
"assets/assets/kartu/poweranta/rayap-toples.png": "a331a87f981693a749f806607e5a0f58",
"assets/assets/kartu/poweranta/roti-surplus.png": "04d4f61b1ced26acd0cd7f33cdf1aa8c",
"assets/assets/kartu/poweranta/ulatbulu-toples.png": "46d922e1e0a433561fec91ae33eaa493",
"assets/assets/kartu/powernight/cerminkhayal.png": "be9a415b3bbef13c5fb45b433f0c5a13",
"assets/assets/kartu/powernight/kameragelap.png": "ca34e0986bcb90dec29e39a267bda5f2",
"assets/assets/kartu/powernight/karungcurianmalam.png": "dcd1020812353af76d8cc07a99006353",
"assets/assets/kartu/powernight/kerikilpanas.png": "b58751f8db0bf5beb7e9f45fda52581d",
"assets/assets/kartu/powernight/pakaianpenyamaran.png": "48a5682ae554a367675a51a28c5e2895",
"assets/assets/kartu/powernight/pindaisalah.png": "04edf16ce959b320113b8d571b64584e",
"assets/assets/kartu/powernight/pompaembun.png": "2e6b4616deda5368709eaad0f9ffc67c",
"assets/assets/kartu/powernight/stetoskoppencurinyawa.png": "fc246a97f4314096d6b73fd368ce58d5",
"assets/assets/kartu/powernight/topengwarga.png": "ea31b67ee7b506db957930bb3218bd3a",
"assets/assets/kartu/powerpro/airsuci.webp": "95bcc3005c8aedfe0388d89e95424a85",
"assets/assets/kartu/powerpro/daunembun.webp": "ccf61791dc8f1eb9b4f508a72fa0bc37",
"assets/assets/kartu/powerpro/doabersama.webp": "ea56357ecb30a72f52bfc12e4b98c568",
"assets/assets/kartu/powerpro/duaikatbungamatahari.webp": "3c5ad3db42c7690a0b794893f3caf571",
"assets/assets/kartu/powerpro/emberair.webp": "8d7aa5bbc2fdc41f6ebc376e13bb05a5",
"assets/assets/kartu/powerpro/esbatukotak.webp": "c1dc128694b13cf279ac6ee3d06a820b",
"assets/assets/kartu/powerpro/gelasembun.webp": "ea2bf76952654ab44b3ab837ed552f0c",
"assets/assets/kartu/powerpro/guntingrumput.webp": "52260714fe301a67d6b804377637509b",
"assets/assets/kartu/powerpro/kacapembesar.webp": "8cea97f8b58edd4fd9aa08cad1aba31c",
"assets/assets/kartu/powerpro/kainkotakhijau.webp": "ec94f74a7cdd90db6f8b526b4ff27a52",
"assets/assets/kartu/powerpro/kapalkertas.webp": "142ac45f271678eab36e5ce7e7368a06",
"assets/assets/kartu/powerpro/kayubakar.webp": "6387565893e61edcd8307c8013f3b2d0",
"assets/assets/kartu/powerpro/kayupagar.webp": "3bf518bd74dd2c6babd1977098883398",
"assets/assets/kartu/powerpro/kotakmedis.webp": "55a300fcc20ade639a319014b415f49f",
"assets/assets/kartu/powerpro/lampusenter.webp": "29dd919338fb49a477a18122832c06f5",
"assets/assets/kartu/powerpro/lemparanasa.webp": "6b3d4803b93253c01bc32b127ea361b3",
"assets/assets/kartu/powerpro/lenteralawas.webp": "2439e3d5f2b7be689d97174a406d696e",
"assets/assets/kartu/powerpro/lilinharapan.webp": "b52aed60367889a26135431f4f22663e",
"assets/assets/kartu/powerpro/pakcacingtanah.webp": "91daefaf537b684e9941172a60f88e45",
"assets/assets/kartu/powerpro/pakdaunkering.webp": "d0702712a59444df4c89c3c5ccce732c",
"assets/assets/kartu/powerpro/penyiramtanaman.webp": "5291aa23c0058e272487ebd62547e13e",
"assets/assets/kartu/powerpro/pupukcair.webp": "0b236a863fb71dd48a9332c45cb35852",
"assets/assets/kartu/powerpro/pupukdaun.webp": "c96060e8473d8b60004b1db4c1775142",
"assets/assets/kartu/powerpro/sekoptanah.webp": "590845013ff0792000ef4cbb85a3a39f",
"assets/assets/kartu/powerpro/semangkukmelati.webp": "70e1a52a3828a066699be4058610700b",
"assets/assets/kartu/powerpro/sinarimitasi.webp": "520e48f2ea1d2e42f03ba73b3b2892fe",
"assets/assets/kartu/powerpro/stetoskop.webp": "da2530cf3011daaf4720028445ee8df6",
"assets/assets/kartu/powerpro/suntikanvaksin.webp": "8fd5a10a810557fcfe2dc92b54b4a141",
"assets/assets/kartu/powerpro/topengtari.webp": "29301e629a5561acf1b464297aa8293d",
"assets/assets/kartu/powerpro/topleskunang.webp": "1e31c69075c73f5ac9abe524eeb72eb3",
"assets/assets/kartu/protagonis/bangsawan-bangsawanpria.webp": "2a62ed965c26f50283c5e4f418ebc06d",
"assets/assets/kartu/protagonis/bangsawan-bangsawanwanita.webp": "95e36b03496d1a687912395c6760b0ba",
"assets/assets/kartu/protagonis/bangsawan-gouverneurpria.webp": "46dd7c1d64ebfb80b5f67f67bb12a788",
"assets/assets/kartu/protagonis/bangsawan-pangeran.webp": "2aff0156091a4bd080d6c1b69f7f9a52",
"assets/assets/kartu/protagonis/bangsawan-pangeranasiatenggara.webp": "3924b832cc624b0fc4179e52748d9f1f",
"assets/assets/kartu/protagonis/bangsawan-pangeranjawa.webp": "d119866f079a2a4b8d75f7ec11eaf2f9",
"assets/assets/kartu/protagonis/bangsawan-pangeranmelayu.webp": "b3b038a77a1c439800b0de8fd1024f5f",
"assets/assets/kartu/protagonis/bangsawan-pangerantailan.webp": "8fbfdc3a4fb7a830293c8d193b567f08",
"assets/assets/kartu/protagonis/bangsawan-pangerantimurtengah.webp": "b6f8429700509b403203e745db95baeb",
"assets/assets/kartu/protagonis/bangsawan-puteri.webp": "fc0f5b7092040fd06d7023b0783376d9",
"assets/assets/kartu/protagonis/bangsawan-puteriasiatenggara.webp": "c6920f17f6e8c866a8e656ed82499069",
"assets/assets/kartu/protagonis/bangsawan-puterijawa.webp": "cafe36d6554ad1537b4f2a8aef751e4b",
"assets/assets/kartu/protagonis/bangsawan-puterimelayu.webp": "9266b695a42e7b2fcfecb34b8fc73146",
"assets/assets/kartu/protagonis/bangsawan-puteritailan.webp": "65e2b6b543d6f7b532cc6ed7e415ff55",
"assets/assets/kartu/protagonis/bangsawan-puteritimurtengah.webp": "d9871713bb5f7b1576ed5bf7bc669b6c",
"assets/assets/kartu/protagonis/buruhangkatwanita.webp": "681805a62eb722045ecc3a81909166d4",
"assets/assets/kartu/protagonis/burungangkatpria.webp": "fac29dd203895f867cbacbb4bc77a567",
"assets/assets/kartu/protagonis/kriyawanpria.webp": "0deac44c018b6a3c7aa02fa5c28d2b62",
"assets/assets/kartu/protagonis/kriyawanwanita.webp": "89fd2e392c96e41be43d253a70515390",
"assets/assets/kartu/protagonis/nelayanikanpria.webp": "0b426e599ff65722ad2f8760fa13859c",
"assets/assets/kartu/protagonis/nelayanikanwanita.webp": "ca0e4561293c31a1c4432dee67e62c8d",
"assets/assets/kartu/protagonis/pekebuntehpria.webp": "5a3a65c06775a8ad8b7a5a52d9d47bab",
"assets/assets/kartu/protagonis/pekebuntehwanita.webp": "43b6e35587d7d66c0042548f8624f127",
"assets/assets/kartu/protagonis/pelukispria.webp": "9c65e81c4f7a688d333daedd9c8cc176",
"assets/assets/kartu/protagonis/pelukiswanita.webp": "2bf87ca669670c32674afe831a74a6a4",
"assets/assets/kartu/protagonis/pemburupria.webp": "2aa353357a97933bcce60807b30a49b0",
"assets/assets/kartu/protagonis/pemburuwanita.webp": "20279f3172ba8bc3795a216b109f07fb",
"assets/assets/kartu/protagonis/penaripria.png": "5afc61183b76efb3a740087684385e12",
"assets/assets/kartu/protagonis/penariwanita.png": "0a37608a12071e6a6a5e7300a4c88d4a",
"assets/assets/kartu/protagonis/penatupria.webp": "3f29e57ce9089d39b388a7085af66459",
"assets/assets/kartu/protagonis/penatuwanita.webp": "7dfbb1dad3e608b066748bd21224010e",
"assets/assets/kartu/protagonis/penenunpria.webp": "79d8886434374034b42b3f77efc14bf9",
"assets/assets/kartu/protagonis/penenunwanita.webp": "5a1f4470ce3dbce5e4fbe87c7add905f",
"assets/assets/kartu/protagonis/penggembalapria.webp": "bd8ae3bd82d72c8551bcd613ec6f2036",
"assets/assets/kartu/protagonis/penggembalawanita.webp": "cc9d048f40b5acd1ce787b6cb86a2274",
"assets/assets/kartu/protagonis/penjagapria.webp": "05375b6b1c136bb8452874d8e81dd188",
"assets/assets/kartu/protagonis/penjagawanita.webp": "223f98591c975b5e10942def3236fdb4",
"assets/assets/kartu/protagonis/penjahitpria.webp": "fc72d50028433e6b2fe22389a12ddbf0",
"assets/assets/kartu/protagonis/penjahitwanita.webp": "592647740607fcb30145f7ac728a8666",
"assets/assets/kartu/protagonis/penjelajahpria.png": "90bf1da32601bf20cf4e51d7f5a397be",
"assets/assets/kartu/protagonis/penjelajahwanita.png": "1ba1449f907c2c65249673a8d425e92c",
"assets/assets/kartu/protagonis/peragawan.png": "7c2a4dbbd8a6dffe99344c4f7bad0c3c",
"assets/assets/kartu/protagonis/peragawati.png": "ccc149cc73e04d4beba106d9944fd0d9",
"assets/assets/kartu/protagonis/perajintembikarpria.webp": "0b6976213088ad03ca6616b7eb3f4c92",
"assets/assets/kartu/protagonis/perajintembikarwanita.webp": "1ce82600fe2e9cb30ca313f2150fba62",
"assets/assets/kartu/protagonis/petanipadipria.webp": "b795acde47b1bcc7447a68948b7f83a0",
"assets/assets/kartu/protagonis/petanipadiwanita.webp": "3c60e4d36ae0a101b8636a348491021a",
"assets/assets/kartu/protagonis/petanirumputlautpria.webp": "356064c4e4c255fa38dd586088024a4d",
"assets/assets/kartu/protagonis/petanirumputlautwanita.webp": "6ce8097368cda699a7c9baf8f1a5e8a2",
"assets/assets/kartu/protagonis/pustakawanpria.webp": "e61dfa63f3046a9eba6c970503afe1b8",
"assets/assets/kartu/protagonis/pustakawanwanita.webp": "acbc617bd9a16a88ca4248fbe091d079",
"assets/assets/kartu/protagonis/wargadesapria.webp": "ecdcd11c467445c96e43599160523657",
"assets/assets/kartu/protagonis/wargadesawanita.webp": "272df08d7940ee58304fc4d7c40851c5",
"assets/assets/kartu/punggungkartu/punggungantagonis.webp": "dffc791a92a27b4eed88b38d9556151a",
"assets/assets/kartu/punggungkartu/punggungitemantagonis.webp": "11c339f8fb812212f3b25f7a8b63e6b6",
"assets/assets/kartu/punggungkartu/punggungitemmalam.webp": "1c95c5327dc582e8e326cf2a7f8e2f39",
"assets/assets/kartu/punggungkartu/punggungitemprotagonis.webp": "d250a76eba033e83ca7987ac91a3622c",
"assets/assets/kartu/punggungkartu/punggungkemampuan.webp": "26779ac688ca326bec4f5300ad8c1e90",
"assets/assets/kartu/punggungkartu/punggungprotagonis.webp": "7555a7bdf6be05249e900ff75c411d31",
"assets/assets/logo/ikon-transparent.webp": "06fa9cbecacc6388b597e86692f539d1",
"assets/assets/logo/ikonapp-transparent.webp": "21d7710de6b473107c3376fe3a48a797",
"assets/assets/logo/logo-linguistichegemony.webp": "eef27a634cb64fedc8a9573c9e9131d4",
"assets/assets/logo/logo-sampahnya.webp": "a82df3f853771fae4cf80299ade0c53b",
"assets/assets/logo/logoteks-transparent.webp": "9849ae3fe81df3c6374be589eb4ec3af",
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
"assets/assets/pohon/pohongerak0.mp4": "65ef12026946455360bc6b736105fac6",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "21ed74fd11c491da306958451f42e3aa",
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
"flutter_bootstrap.js": "db5ae54faee4cd946b9b428b29c92666",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "de5cd924341a6010f14615fdbbbc0952",
"/": "de5cd924341a6010f14615fdbbbc0952",
"main.dart.js": "d72f5c6d9a09f5439804cd3bd62cbe69",
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
