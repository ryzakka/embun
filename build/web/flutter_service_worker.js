'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "6c03a97e6142018ee3d27469f8a8d039",
"assets/AssetManifest.bin.json": "05b1bbcaa8985d6f5c95e07aa479dbe4",
"assets/assets/bentang/alunalun-tiangberpita.webp": "250ce118405c1d83668adf39ad9a40ff",
"assets/assets/bentang/anyaman-gelap.webp": "5322aff6e036276cb3e8960a77599f9b",
"assets/assets/bentang/anyaman-rusak.webp": "21b76bbe9458a9952369cf8d1b451492",
"assets/assets/bentang/anyaman-temaram.webp": "7528bfbcd78de6ff8112927a54f9e9fe",
"assets/assets/bentang/ayakanrotan-temaram.webp": "ef5ef128445015550b9b6668f0775b23",
"assets/assets/bentang/balaidesa-dalamsiang.webp": "d50b9aad29b97e0f14dd847e777fade9",
"assets/assets/bentang/balaidesa-luarsiang.webp": "50e73983aec67143f0b9ac609b7a45ee",
"assets/assets/bentang/bingkai-layu.webp": "ae922b8f872969d27aa122aa09146444",
"assets/assets/bentang/bingkai-subur.webp": "9728d41090c9184d9ae01f2855fa409c",
"assets/assets/bentang/desajembatan-kering.webp": "3dff3ab0c7348bd2d8b30043e205146d",
"assets/assets/bentang/desajembatan-keringgulita.webp": "5ff23b12066b69e4e292c987677949c6",
"assets/assets/bentang/gerobakdankeranjang.webp": "a5ec1806db6a89dcb2774658a15c00c5",
"assets/assets/bentang/jalanjauhdesa.webp": "266b37dcf190be4c54cf1664dfc637fb",
"assets/assets/bentang/kamarkayudesa.webp": "d8ab9b1fd6497f2e33870a051561f473",
"assets/assets/bentang/kertaslusuh.webp": "9798f330bb7daad2353d2643af15b534",
"assets/assets/bentang/keterasingan.webp": "bc50f5c5ca5777d75a18c59888b7eedc",
"assets/assets/bentang/kuali-racikan.webp": "8fcbab4f60e4cc7c130b94c9f0117fcf",
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
"assets/assets/bentang/mejaku.webp": "3d743c23e52e9da1de9e42729facfdbb",
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
"assets/assets/bentang/tertunjuk.png": "1c55320ced36c1017fa5bbcd8ad710ff",
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
"assets/assets/kartu/CharAnta/kegelapan1.webp": "4dba1fe2d393d2979376dd7b7189f36a",
"assets/assets/kartu/CharAnta/kegelapan10.webp": "8ea9bd7f195d58726da5f0436be7cff7",
"assets/assets/kartu/CharAnta/kegelapan11.webp": "528b6593190e952cc82f09318e0d41ee",
"assets/assets/kartu/CharAnta/kegelapan12.webp": "4c3087db72c5a688a59d960677feb2e3",
"assets/assets/kartu/CharAnta/kegelapan13.webp": "73cee4a68d7778e33408a3228b31f002",
"assets/assets/kartu/CharAnta/kegelapan14.webp": "316ceca67a9cef77bfce1aa625f1e7c6",
"assets/assets/kartu/CharAnta/kegelapan15.webp": "bd59fce5c2c31c02059c813a3527cb34",
"assets/assets/kartu/CharAnta/kegelapan16.webp": "7eea3d567c09e9ee7e35f75f6ed053a4",
"assets/assets/kartu/CharAnta/kegelapan17.webp": "71f2b090818f7631d7b3fb707e8a1f8f",
"assets/assets/kartu/CharAnta/kegelapan18.webp": "0cea6964a767d80bedcca0cda6e329bc",
"assets/assets/kartu/CharAnta/kegelapan19.webp": "a4f49aa163dee127b0a1aa37d0fbdaea",
"assets/assets/kartu/CharAnta/kegelapan2.webp": "002e032d0703c66ba890ef9c5788b04e",
"assets/assets/kartu/CharAnta/kegelapan20.webp": "0f72e807802367c95c5256efc2bade80",
"assets/assets/kartu/CharAnta/kegelapan21.webp": "e46c35154c7e88f8086bb6cf9e270ce7",
"assets/assets/kartu/CharAnta/kegelapan22.webp": "f943e547abcf75716cf3db2b74c5d33b",
"assets/assets/kartu/CharAnta/kegelapan23.webp": "1541788c20efef48df26fdc4da138b17",
"assets/assets/kartu/CharAnta/kegelapan24.webp": "72906a85946af40c87740f133c2dbdea",
"assets/assets/kartu/CharAnta/kegelapan25.webp": "329f0d91e5436e127838bcb4099ef80d",
"assets/assets/kartu/CharAnta/kegelapan26.webp": "8e716037c189a1bea24aaf6517ab8167",
"assets/assets/kartu/CharAnta/kegelapan27.webp": "1bfefa43283fce58d75a14c6f5be7f57",
"assets/assets/kartu/CharAnta/kegelapan28.webp": "4d051e3a8e75cd654a7e3330ff035a3d",
"assets/assets/kartu/CharAnta/kegelapan29.webp": "d16c9682549b5bd891652f7453ec7d47",
"assets/assets/kartu/CharAnta/kegelapan3.webp": "5255e0d56187bd9baa84f4e9481f93d8",
"assets/assets/kartu/CharAnta/kegelapan30.webp": "2e9d6bad046568b4c42175e59a7916ff",
"assets/assets/kartu/CharAnta/kegelapan4.webp": "0b0c49790dadbe938970bac8b333d8d1",
"assets/assets/kartu/CharAnta/kegelapan5.webp": "a013059a4890105cff3f287368e3e532",
"assets/assets/kartu/CharAnta/kegelapan6.webp": "932220569ae9eae51f664551accdb753",
"assets/assets/kartu/CharAnta/kegelapan7.webp": "a67ac6051e3ae331dfe9808dc6ffa7c9",
"assets/assets/kartu/CharAnta/kegelapan8.webp": "da3e837f0c2af59972dfa0ea5c36d4ec",
"assets/assets/kartu/CharAnta/kegelapan9.webp": "9918cb1909f870a4da7d6200c89965ac",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-ilmuwan.png": "6d5a1e843a1c8743c615f671406bc125",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-mastersauna.png": "fab99c557e451c7851e94ea9d501680e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-matamata.png": "635ef475ad49d21d61d596b2106b18f0",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayan.png": "37773bc10bebf53d4051a838054db171",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanlautdalam.png": "7e24a2be4dc173f2b09f10bdf5aaca1b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pandaibesi.png": "f0599b7ca275019636c9eb6ed29838ce",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemahatbatu.png": "6a76b267aa04d2d955c2387928d70958",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemburu.png": "f83a750f4f12d07cb517cac615836ea1",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penambangemas.png": "885f6caeaba7f17d7bf7e8dc2e3e12cb",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penari.png": "c024c59ef930c66fcdb41552597045b0",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penatu.png": "f0d813676ee973db07330d4b4bcb8839",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penenun.png": "3cb20006504d13f789f4bf586a444706",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggembala.png": "e8a37c26c4d2334ce239f292130ce9be",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pengukirkayu.png": "37f6ff07d94facfe080ddd4169dfe086",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjaga.png": "f2c9178465529b9bcb3f280ffb4da432",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjahit.png": "d73dd98feb312caa1afdc8a1de67b36b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjelajah.png": "b582247b28e2a56279287c92315aaa8e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peracik.png": "b95712c2d80312240a62eea33e1fe352",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peraga.png": "7c2a4dbbd8a6dffe99344c4f7bad0c3c",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perajintembikar.png": "ba426cd0a7653ac93c69aefc273baa68",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peselancar.png": "c06904220b6055c9e7accaf605d09051",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanirumputlaut.png": "c1db2d9d01ff16d9f72e4d4942a788b7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakkelinci.png": "dc2120fcb9eca97ef020dd4dd5617d92",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukangdaging.png": "3fc4f0adc1f182b373797eae6dc40e6e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-wargadesa.png": "63b291838fbce10ff9ee4c47613e5f4e",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-nelayan.png": "5b71953bc60660a6d3a7b30a14a47539",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pelukis.png": "2d23ca32362b6fdba483357039657221",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pemburu.png": "915182c7c7cb82e8d34eb12a7078924e",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penari.png": "0a37608a12071e6a6a5e7300a4c88d4a",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penatu.png": "6ab4773d55bf529cb78e266cb4545b3c",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penenun.png": "5b02de0b9465a24d26fc8f9f40aa4c3a",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pengajar.png": "1558e3ef3a246ba2303a61cc4c5ab44c",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penggembala.png": "8b060d6a9a69725ff3ec907f9b6b1c0f",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjaga.png": "1ebaf53bac52da4b267da0c25b71871c",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjahit.png": "98191c2e4224af5fdce973b2d1f469c9",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjelajah.png": "1ba1449f907c2c65249673a8d425e92c",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-peraga.png": "ccc149cc73e04d4beba106d9944fd0d9",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-perajintembikar.png": "b0597ae182468238ee3996643cd57e2b",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-petani.png": "8cc16c6fa87d30fb29f2e6cbb41de15d",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-petanirumputlaut.png": "902164918e1de3cd9ca0eeaa5c6c06d9",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-wargadesa.png": "6366cef90025d6b50437904b84fb20f2",
"assets/assets/kartu/CharSkill/kemampuan1.webp": "863ccfabcc7debf49506d459684eb94d",
"assets/assets/kartu/CharSkill/kemampuan10.webp": "ec8e61aa2636dff99444e986493e1375",
"assets/assets/kartu/CharSkill/kemampuan11.webp": "080b35df33338a1e23953cd7a4273cfc",
"assets/assets/kartu/CharSkill/kemampuan12.webp": "104a291adea0cc58119c8d6ed890ac97",
"assets/assets/kartu/CharSkill/kemampuan2.webp": "38f71102646269c01fc7a5723be4a2a3",
"assets/assets/kartu/CharSkill/kemampuan3.webp": "92fb1e7a166753d40892ce854cd98cfb",
"assets/assets/kartu/CharSkill/kemampuan4.webp": "b2d28a1d58ca151c0a4920d6edb222ca",
"assets/assets/kartu/CharSkill/kemampuan5.webp": "71d44006602fae33d528316c577f85d4",
"assets/assets/kartu/CharSkill/kemampuan6.webp": "127f0e95f199e13f944b52e726ad64d6",
"assets/assets/kartu/CharSkill/kemampuan7.webp": "0d99054d01763ad67f980d787551c3b8",
"assets/assets/kartu/CharSkill/kemampuan8.webp": "00f92ba13701d781c32c49b8d6b61969",
"assets/assets/kartu/CharSkill/kemampuan9.webp": "9dd3475e8c7b3f85a1bedff05a5757b4",
"assets/assets/kartu/ItemAnta/asam-jerigen.webp": "b1544fa9dac1cae034fabef637383838",
"assets/assets/kartu/ItemAnta/bisikan.webp": "14737e97f7d9f57cb1f3cd6e8ad44792",
"assets/assets/kartu/ItemAnta/boneka-sawah.webp": "5c61c1238d84611afac413930c621ba5",
"assets/assets/kartu/ItemAnta/boneka-voodoo.webp": "7a3f733d09a9cd1b9a683f9f00ad925d",
"assets/assets/kartu/ItemAnta/bulirhitam-drum.webp": "ccbab2c3e56cd72aa4eb0e405825ac85",
"assets/assets/kartu/ItemAnta/bulirhitam-ember.webp": "6dcfc32f81ca283f2e32724bddf851e4",
"assets/assets/kartu/ItemAnta/bulirhitam-emberbesar.webp": "39150171363854e02f2e805a890ba48d",
"assets/assets/kartu/ItemAnta/bulirhitam-gelas.webp": "115a23b6ab24fe9492cfa9936f39d9dc",
"assets/assets/kartu/ItemAnta/cangkul.webp": "d2099398da2eb555621434ac4e64d80f",
"assets/assets/kartu/ItemAnta/gergaji-manual.webp": "6a5014daa7cb95be2871b140a73da11e",
"assets/assets/kartu/ItemAnta/gergaji-mesin.webp": "852540113c437c9953717df1a52ba795",
"assets/assets/kartu/ItemAnta/jahit-keranjangjahit.webp": "8c5f9459d2be50b3798c36d1c1dd0b5f",
"assets/assets/kartu/ItemAnta/kapak.webp": "02e830f822f647551712bb75d2409902",
"assets/assets/kartu/ItemAnta/kawatberduri.webp": "1bac837e3f8c3d54d0865cce2abe6aae",
"assets/assets/kartu/ItemAnta/kontaminasi-kain.webp": "fb697069dde691282ea027923168f184",
"assets/assets/kartu/ItemAnta/pengguntingrumput-mesin.webp": "1b4bb177a6f95aadc30f398af9ac795e",
"assets/assets/kartu/ItemAnta/pupukpalsu-karung.webp": "3972df92f196312695a50a84b2ac5d7a",
"assets/assets/kartu/ItemAnta/pupukpalsu-karungganda.webp": "c44cd5e9d693a1a4fe01c8c20df60d45",
"assets/assets/kartu/ItemAnta/racun-drum.webp": "6e8831321ccf41e260e0cf0aeaf57c0c",
"assets/assets/kartu/ItemAnta/racun-ember.webp": "a135a706ef046379d6db4a19596ea279",
"assets/assets/kartu/ItemAnta/racun-sekop.webp": "0a035ae87d2f24e9eb270b2828b27d9e",
"assets/assets/kartu/ItemAnta/racun-semprotan.webp": "c8dccf3f0fdf9790cfa55b022b4e6953",
"assets/assets/kartu/ItemAnta/racun-sudip.webp": "95868877a35006ddbca763abe1227707",
"assets/assets/kartu/ItemAnta/racun-suntik.webp": "4fae2800fec794e459b14aaf53319362",
"assets/assets/kartu/ItemAnta/ramuan-hitampeningkatan.webp": "544dc42f47994264828670bcdca21f45",
"assets/assets/kartu/ItemAnta/ramuan-ungumistispercepatan.webp": "cba4dc849a7b776da8dbe3c4a740be42",
"assets/assets/kartu/ItemAnta/rayap-toples.webp": "97538506ea4c93635f63448e2ecf7b78",
"assets/assets/kartu/ItemAnta/roti-surplus.webp": "186b74938cf77e739712cbb7040a5b3c",
"assets/assets/kartu/ItemAnta/ulatbulu-toples.webp": "3822a240d16b728939a2f832c0aab4f3",
"assets/assets/kartu/ItemAntaNight/cerminkhayal.webp": "eb8ff9cf08422762315982c46214eb91",
"assets/assets/kartu/ItemAntaNight/kameragelap.webp": "c303b26e5d51873946f83e384d8bcb5c",
"assets/assets/kartu/ItemAntaNight/karungcurianmalam.webp": "e05ccdff8c589ee130b2c3e74eaad7d6",
"assets/assets/kartu/ItemAntaNight/kerikilpanas.webp": "71e73f2230aa96779fc7569081acc071",
"assets/assets/kartu/ItemAntaNight/pakaianpenyamaran.webp": "078504bb39b78f0ba2574b8bad76919a",
"assets/assets/kartu/ItemAntaNight/pindaisalah.webp": "9120f7297562542982c0e06ab3453de4",
"assets/assets/kartu/ItemAntaNight/pompaembun.webp": "45c8f2952eeba4ee43ce922dc5faf2e0",
"assets/assets/kartu/ItemAntaNight/stetoskoppencurinyawa.webp": "32bffd9cd3cb2717ffbdac24cc55e076",
"assets/assets/kartu/ItemAntaNight/topengwarga.webp": "bfe4d27cd49c4c3494bfa38be9735560",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-angin.png": "0124f30711855dba163a940c3317674f",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-cuaca.png": "a4baf0225959baada64b06646a190cf7",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-daun.png": "286534f0cd899c6d774fcbd758b3c37c",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-drone.png": "7c59317d97b8169a3c94ed8e5a910005",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-genetika.png": "1ad047af0249da7b75ea1f3349a6ac4c",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-kapsuldna.png": "24fc0315a84eb1160d3565ed7fb94b48",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-karbon.png": "656db10858042471325690ea8ab97176",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-poindna.png": "f94dee461cddadfa2982a7b141788bdf",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-tanah.png": "b9dbb2c6fecc091e7b32173c819f7df2",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-ulat.png": "f22eec66786f113fff9b566f0d4e08aa",
"assets/assets/kartu/ItemPro/airsuci.webp": "f21d80d6432fdda0cb76ef84449f7d34",
"assets/assets/kartu/ItemPro/daunembun.webp": "46f720fca5051c56b2d4614ad2d22fe4",
"assets/assets/kartu/ItemPro/doabersama.webp": "a6544cdae9843f63911a54a14b1d5516",
"assets/assets/kartu/ItemPro/duaikatbungamatahari.webp": "ea0010e5f85edef9b86b3b27d054fd6d",
"assets/assets/kartu/ItemPro/emberair.webp": "8d7aa5bbc2fdc41f6ebc376e13bb05a5",
"assets/assets/kartu/ItemPro/esbatukotak.webp": "1c7dfe8997513cded48a894ad9096d51",
"assets/assets/kartu/ItemPro/gelasembun.webp": "672740d2cecf1b802a1c326279213ea2",
"assets/assets/kartu/ItemPro/guntingrumput.webp": "52260714fe301a67d6b804377637509b",
"assets/assets/kartu/ItemPro/ikanemas.webp": "c76f453a3800de57a785fe66ee304cba",
"assets/assets/kartu/ItemPro/kacapembesar.webp": "59d5afdf28f4c380d3690ce5b6b3de18",
"assets/assets/kartu/ItemPro/kainkotakhijau.webp": "ec94f74a7cdd90db6f8b526b4ff27a52",
"assets/assets/kartu/ItemPro/kapalkertas.webp": "5decdf32c526cbb33cb75ef047f5187c",
"assets/assets/kartu/ItemPro/kayubakar.webp": "c60312cbb744dadac16e79dc7961a5d0",
"assets/assets/kartu/ItemPro/kayupagar.webp": "3bf518bd74dd2c6babd1977098883398",
"assets/assets/kartu/ItemPro/kotakmedis.webp": "55a300fcc20ade639a319014b415f49f",
"assets/assets/kartu/ItemPro/lampusenter.webp": "29dd919338fb49a477a18122832c06f5",
"assets/assets/kartu/ItemPro/lemparanasa.webp": "6b3d4803b93253c01bc32b127ea361b3",
"assets/assets/kartu/ItemPro/lenteralawas.webp": "a69d80af63afda579875cd75960e4739",
"assets/assets/kartu/ItemPro/lilinharapan.webp": "325e9e46bb7e521e80faf06e942f33df",
"assets/assets/kartu/ItemPro/pakcacingtanah.webp": "91daefaf537b684e9941172a60f88e45",
"assets/assets/kartu/ItemPro/pakdaunkering.webp": "74ee85c33d67762e0ac765561b2b383b",
"assets/assets/kartu/ItemPro/penyiramtanaman.webp": "5291aa23c0058e272487ebd62547e13e",
"assets/assets/kartu/ItemPro/pupukcair.webp": "07416f8460a5282671683f7b9de0060e",
"assets/assets/kartu/ItemPro/pupukdaun.webp": "c96060e8473d8b60004b1db4c1775142",
"assets/assets/kartu/ItemPro/sekoptanah.webp": "590845013ff0792000ef4cbb85a3a39f",
"assets/assets/kartu/ItemPro/semangkukmelati.webp": "545329bfb0b67755b259a303a6b16ae6",
"assets/assets/kartu/ItemPro/sinarimitasi.webp": "520e48f2ea1d2e42f03ba73b3b2892fe",
"assets/assets/kartu/ItemPro/stetoskop.webp": "da2530cf3011daaf4720028445ee8df6",
"assets/assets/kartu/ItemPro/suntikanvaksin.webp": "8fd5a10a810557fcfe2dc92b54b4a141",
"assets/assets/kartu/ItemPro/topengtari.webp": "29301e629a5561acf1b464297aa8293d",
"assets/assets/kartu/ItemPro/topleskunang.webp": "9a2e90f701ca47ef570c263c3653f1dc",
"assets/assets/kartu/ItemProDay/busurterakhir.png": "ae89951346ecc1e2387e173748e071a1",
"assets/assets/kartu/ItemProDay/cerminkecil.png": "a43da368e5a8112a95bec82adf6e5ea4",
"assets/assets/kartu/ItemProDay/jerikenembun.png": "bfae827e57d2a5d9b3b7070479ed6807",
"assets/assets/kartu/ItemProDay/keranjangbaru.png": "434ca6efe453d58c4698d79162d3e1fd",
"assets/assets/kartu/ItemProDay/perlindunganmalam.png": "848d5be9d4b45de102b4648f73af2d7f",
"assets/assets/kartu/ItemProDay/topleshati.png": "d651131f54bb374d39e5572c65701400",
"assets/assets/kartu/ItemProRegenerasi/gen-abmix.png": "0ffbc96a7250b8ac061f912594933380",
"assets/assets/kartu/ItemProRegenerasi/gen-bacillusthuringiensis.png": "5f17acf22ab1a1ac106c31a7565862d9",
"assets/assets/kartu/ItemProRegenerasi/gen-bibitlab.png": "a85c2bcc4049cb911e3e18ca7b5f7196",
"assets/assets/kartu/ItemProRegenerasi/gen-biofortifikasi.png": "9306c81a60e67a4e9be4276f480d9370",
"assets/assets/kartu/ItemProRegenerasi/gen-dronepengusirhama.png": "7b65a66ae2cc409d78fc6c464b6e2f58",
"assets/assets/kartu/ItemProRegenerasi/gen-dronepenyiramtanaman.png": "cb10f4798f61810e998d78eb7ee2c16d",
"assets/assets/kartu/ItemProRegenerasi/gen-genomediting.png": "d3ff9a7dd4028fe37ca7abf407ece639",
"assets/assets/kartu/ItemProRegenerasi/gen-lacticacid.png": "21d4e3c8812694e1920bc0e115058c9c",
"assets/assets/kartu/ItemProRegenerasi/gen-mediakultur.png": "ed9f0c1b09c4b8a57dd01ce3413a96a7",
"assets/assets/kartu/ItemProRegenerasi/gen-poinregenerasi.png": "5f35166b6bfd2a2c2f141ef47405416a",
"assets/assets/kartu/ItemProRegenerasi/gen-pupukeco.png": "199f4882acbc0e3677567ae78bcad341",
"assets/assets/kartu/ItemProRegenerasi/gen-semprotannanokarier.png": "58f8d7b59291156be101eb349f8a9079",
"assets/assets/kartu/ItemProRegenerasi/gen-soilmoistureprobe.png": "61de99c6ebf0e31555e72e64857c7232",
"assets/assets/kartu/punggungkartu/punggungantagonis.webp": "57ae2dd4ccd557b2d68ac186d35c0b64",
"assets/assets/kartu/punggungkartu/punggungitemantagonis.webp": "57ae2dd4ccd557b2d68ac186d35c0b64",
"assets/assets/kartu/punggungkartu/punggungitemmalam.webp": "2659aa582be21e8258cb5d82bee3f467",
"assets/assets/kartu/punggungkartu/punggungitemprotagonis.webp": "7555a7bdf6be05249e900ff75c411d31",
"assets/assets/kartu/punggungkartu/punggungitemsiang.webp": "46a095fec4f2eb35fe858a9abd96ed51",
"assets/assets/kartu/punggungkartu/punggungkemampuan.webp": "0a22373396e9fa2434e01c359b90adf7",
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
"assets/assets/sound/backsound01.mp3": "b32732d10a7bc3f82b3c684a1e91d063",
"assets/assets/sound/buy.mp3": "48a6ccae7f4f7ec93e2090aeed6b3a24",
"assets/assets/sound/clickbutton-tung.mp3": "338ceb9aa86a75c4573787299c29f0e3",
"assets/assets/sound/clickbutton.mp3": "d50d2b27c56ad9024449ea9081c6944a",
"assets/assets/sound/clickbutton2.mp3": "32cc5216fc91b985c104d127c71f1972",
"assets/assets/sound/dentumanmelodivoting.mp3": "f0a63bfca52dda0bff3bc580268cfa19",
"assets/assets/sound/dentumpagarpenjara.mp3": "cc80a71ed7a180cfd562f62c595edbd6",
"assets/assets/sound/fairygrow.mp3": "d36bcc19f042fab3c1fce9c1838043f9",
"assets/assets/sound/latarakhirendingstatistik.mp3": "8dc19f19a272d80ef0241aed27a8fd55",
"assets/assets/sound/latarprologawal.mp3": "b2f1a9b1978cc02d580b7121239db263",
"assets/assets/sound/prolog-narasibicara.mp3": "49539ea3d61ee6fe5d9a2ab89c67ef2f",
"assets/assets/sound/slashgemerciklight.mp3": "c78ee7e75b5e5d4cba73e273dcc526f1",
"assets/assets/sound/slashpedang.mp3": "7d3209777e8632c8eb69e093eb4268f7",
"assets/assets/sound/swingfire1.mp3": "a7524082ada12b928165ad78e8aa1894",
"assets/assets/sound/swingfire2.mp3": "3d0247c57bd51d94b7e810b859723cbe",
"assets/assets/sound/swingwind1.mp3": "9bdc89ded9f25e4ee774340fa6b5395e",
"assets/assets/sound/swingwind2.mp3": "a11b8c9f45869a3479b52a2c0ae37aba",
"assets/assets/sound/swingwind3.mp3": "648d04692ec9b83b24cd66d2c71a178e",
"assets/assets/sound/thunder.mp3": "920ff2fbe71c1cf5a0b5f91f2e7abf9c",
"assets/assets/sound/timermendekatihabis.mp3": "2474ffaba99a08630492d100ae13ef28",
"assets/assets/sound/timermendekatihabis2.mp3": "eddf74b96f87656bba45853f26a4f389",
"assets/assets/sound/voice-halo.mp3": "6030376150445a964bb49beee3c512ea",
"assets/assets/sound/voice-mulai.mp3": "18e5c7e064daac6623a864a52cc0302a",
"assets/assets/sound/voice-siap.mp3": "c8cc7638075c8b0cc79f19e91099d615",
"assets/assets/sound/voice-tunggu.mp3": "2dfe2f04a1a847b5253414e236eee343",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "67a283430b446578bf022c6caa1fea90",
"assets/NOTICES": "0722e107771ddfd2c4528f64c9327b8d",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/atmosphere.frag": "307d9eabb754625428c7d4d8bb7e8bc8",
"assets/shaders/card_morph.frag": "87a70bf9d6bbb82535dfc51c440fab12",
"assets/shaders/cloth.frag": "191dcc44ed89406f8ba6267525bb98e0",
"assets/shaders/divine.frag": "1df92c3ac40f5d583a4a1491b4bb35a1",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/omen_sky.frag": "d775682af63b4d82fb42a94c36c06323",
"assets/shaders/prologue_fx.frag": "6b757542d5b571cc693bdf42506f9a4b",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/vote_reveal.frag": "c304d24461a59dcc44b22d85b7ca266b",
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
"flutter_bootstrap.js": "b231ba74177c523b8cd95234cdcb2aed",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "de5cd924341a6010f14615fdbbbc0952",
"/": "de5cd924341a6010f14615fdbbbc0952",
"main.dart.js": "961065b01ca82e1b7e46858b1c2a574d",
"manifest.json": "df5ecdba13a1656c0809325677030ab9",
"version.json": "274fdcc09e121db6177e9ac0d79e27b5"};
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
