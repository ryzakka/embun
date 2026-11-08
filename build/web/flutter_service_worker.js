'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ac0fe5c61f84f5cb365541eb9d3fc8da",
"assets/AssetManifest.bin.json": "106f42427238412a24968a28781b3080",
"assets/assets/bentang/alunalun-tiangberpita.webp": "250ce118405c1d83668adf39ad9a40ff",
"assets/assets/bentang/anyaman-gelap.webp": "5322aff6e036276cb3e8960a77599f9b",
"assets/assets/bentang/anyaman-rusak.webp": "21b76bbe9458a9952369cf8d1b451492",
"assets/assets/bentang/anyaman-temaram.webp": "7528bfbcd78de6ff8112927a54f9e9fe",
"assets/assets/bentang/ayakanrotan-temaram.webp": "ef5ef128445015550b9b6668f0775b23",
"assets/assets/bentang/balaidesa-dalamsiang.webp": "d50b9aad29b97e0f14dd847e777fade9",
"assets/assets/bentang/balaidesa-luarsiang.webp": "50e73983aec67143f0b9ac609b7a45ee",
"assets/assets/bentang/balkon-siang.webp": "dd33f1f65191475a0c11448f272dd82d",
"assets/assets/bentang/bingkai-layu.webp": "ae922b8f872969d27aa122aa09146444",
"assets/assets/bentang/bingkai-subur.webp": "9728d41090c9184d9ae01f2855fa409c",
"assets/assets/bentang/desajembatan-kering.webp": "3dff3ab0c7348bd2d8b30043e205146d",
"assets/assets/bentang/desajembatan-keringgulita.webp": "5ff23b12066b69e4e292c987677949c6",
"assets/assets/bentang/gerobakdankeranjang.webp": "a5ec1806db6a89dcb2774658a15c00c5",
"assets/assets/bentang/hantu-jeramidiladang.webp": "cae3c578558ecd3b5bf33ba2ef6ca342",
"assets/assets/bentang/hantu-jeramigerakdiam.webp": "63914e6735cb5b3dac98a818c07876b5",
"assets/assets/bentang/hantu-manusiaberbadansetengahkuda01.webp": "4d4c97ff83207b0d1ffc5f009d6bc52e",
"assets/assets/bentang/hantu-perempuanbertopengdiatasrakbuku.webp": "99877411481d19244162181e3428dd0f",
"assets/assets/bentang/hantu-perempuankeluarsumur.webp": "f0d942dbbe31f618d57e6fd470d11e23",
"assets/assets/bentang/hantu-priapenggodadikamar.webp": "b2ba6ca6779bab76e0e9f4987990eab1",
"assets/assets/bentang/hantujeramigerakmaju.webp": "5152a8845778aa66d270dc167726a65c",
"assets/assets/bentang/hantumurka-perempuanbungameraih.webp": "7892ac378667c1d9439e3fa93f14c50d",
"assets/assets/bentang/hantumurka-topengpria.webp": "a182550e335bd8ef879627991ab448f7",
"assets/assets/bentang/hantumurka-wanitatopengjubah.webp": "a055a541c8eb817f7ad2a3ba54e4df8b",
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
"assets/assets/bentang/lembah-hantumurka.webp": "3284064b978fb081e050bfabf32405a1",
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
"assets/assets/bentang/tertunjuk.webp": "0dae13153d6fee16bcf8e08bd19520d6",
"assets/assets/ikon/addmember.webp": "47729f3106f84819a636fdecc21278c6",
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
"assets/assets/ikon/jointoroom.webp": "29b2502c8033d21fd84dbdae58ffa3bc",
"assets/assets/ikon/kalah.webp": "72f904834a2208891e13beb2970a539c",
"assets/assets/ikon/keluar.webp": "f603e8ddcd61581d01d72560d6b071a9",
"assets/assets/ikon/kirim.webp": "b76726c92c5ad7f193412bc9e9f59d51",
"assets/assets/ikon/lock.webp": "1f8d0c3437198c31fd25c1e4928b5ddb",
"assets/assets/ikon/logorhistory.webp": "3aa3aced314228f94b71b7af0ea765b9",
"assets/assets/ikon/menang.webp": "daf3280b4f0ad904bb2c046cd824f530",
"assets/assets/ikon/menu.webp": "53b1eb380e4e80dbe48701739f5ff14b",
"assets/assets/ikon/minus.webp": "318360dd83fbb4d1b94f136cfb9d0114",
"assets/assets/ikon/mydeck.webp": "fc4ed23279cc25880220363f1cb0f364",
"assets/assets/ikon/mydeck2.webp": "f0cfd8913005efd5d1f0f76a78aa3cbc",
"assets/assets/ikon/notification.webp": "fbe51bb500705fef49f6f13a6ded5c8c",
"assets/assets/ikon/persona.webp": "c3d9ba4632b8fdb87c6e519d2b80c2c8",
"assets/assets/ikon/plus.webp": "f556ebd6e47639d040f9bfab61fdbeb8",
"assets/assets/ikon/poinmin1.webp": "d149a81efcc2ae28be88acfd8f454cf7",
"assets/assets/ikon/poinplus1.webp": "a06e4a6e6bd6d004ac91863e38d0861a",
"assets/assets/ikon/question.webp": "d33024eea2cf7300209296d13590d5f5",
"assets/assets/ikon/refresh.webp": "1adcd63cfa23413086d300b65a022178",
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
"assets/assets/ikon/tutor.webp": "6ce62a0a5b9848873d7a19ff4d24df8b",
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
"assets/assets/kartu/CharPro/CharPro-Pria/pria-ilmuwan.webp": "1a3f5e61b008516f2e658f6d30996078",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-mastersauna.webp": "4b28ff4d2d008b56fda3419070a63923",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-matamata.webp": "4e0a3aea007152d3774ef5fc4e24256d",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayan.webp": "cf2c5c93cc9d2af7f5eb70ea55c0fac3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanlautdalam.webp": "6ae8b4310563434afbbf3c92e59e45c7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pandaibesi.webp": "bc4b7f85f9666b44389ab5f482cfa714",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemahatbatu.webp": "261cdd420a48fbe0bb70bde7b972e43f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemburu.webp": "efea7514a2cb933d742a599fa2b9c401",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penambangemas.webp": "5288aa0fed832d376ddb8e55d93826c8",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penari.webp": "5b45e593a3c079945b6b6e8695aa4c24",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penatu.webp": "f4b8e0a220331df8036cec27908bd721",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penenun.webp": "94a1e7141e6790d2aa8dcf2d1c563e88",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggembala.webp": "3df7822f6d7b014dce1c41c22ad3a1f5",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pengukirkayu.webp": "a5529564112c949535606ecf0f6d62fa",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjaga.webp": "b98a1d7b3a2afec924b3fc67045f754d",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjahit.webp": "b80cf838013cec2f2f402ebf6033f57e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjelajah.webp": "031bc9798858841d2ee17a1fee6130eb",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peracik.webp": "24bd4e0503c3082e4b019fb64b329865",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peraga.webp": "73750c1371f96e7bd7a6e65ffd526561",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perajintembikar.webp": "a7ab9978cb39fe3f6f76ec251604a06d",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peselancar.webp": "f80c15a0fd26b7723dd9376288b36260",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanirumputlaut.webp": "9686e0c9ba7e66ab074cd6cb97b86b62",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakkelinci.webp": "874d10c701bf3878327cf6121949366d",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukangdaging.webp": "6dcc363f0ec58ec6bb55cd9c5e8f02ef",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-wargadesa.webp": "ff57e6c36dcbfb1440ca8aacae65fa8f",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-nelayan.webp": "857f4426cba62cbb459e4be278add2eb",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pelukis.webp": "2bf87ca669670c32674afe831a74a6a4",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pemburu.webp": "20279f3172ba8bc3795a216b109f07fb",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penari.webp": "416b0920e1a42bd03e93987a7888f729",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penatu.webp": "7dfbb1dad3e608b066748bd21224010e",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penenun.webp": "5a1f4470ce3dbce5e4fbe87c7add905f",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pengajar.webp": "9bebd2f8449307fa44842e271999b80d",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penggembala.webp": "cc9d048f40b5acd1ce787b6cb86a2274",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjaga.webp": "223f98591c975b5e10942def3236fdb4",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjahit.webp": "592647740607fcb30145f7ac728a8666",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjelajah.webp": "b050c11a0b2a3876f212c78c7173d688",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-peraga.webp": "f2cb40f64b2b28671fb248a96ce62c97",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-perajintembikar.webp": "1ce82600fe2e9cb30ca313f2150fba62",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-petani.webp": "3c60e4d36ae0a101b8636a348491021a",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-petanirumputlaut.webp": "6ce8097368cda699a7c9baf8f1a5e8a2",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-wargadesa.webp": "592afa4714ebc0b7cef7f1d478e01d3c",
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
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-angin.webp": "4891645cd0870099430ea070af0c0153",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-cuaca.webp": "9cd29c4b027e64a45799d8dcae028b85",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-daun.webp": "951d70801b18e121413f97ec251c090e",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-drone.webp": "dd0746cdbe302961a98ecd60e938729d",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-genetika.webp": "f6fe79e618e732f59a8b63cbe0473b4a",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-kapsuldna.webp": "5b316b55651a9c856dc6b98d5f0880db",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-karbon.webp": "8e2a36e8c2c96723f5671d43de2c2434",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-poindna.webp": "b0c9db98e25f1bb7da0b0f584525d89f",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-poindna2.webp": "1e9f3eb620c648644d475c81f71e7ac4",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-tanah.webp": "35b94eb94c4d53c970a0b717579278f2",
"assets/assets/kartu/ItemAntaRekayasa/rekayasa-ulat.webp": "a5dbdcc764a4200832e514ab77f3f97e",
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
"assets/assets/kartu/ItemProDay/busurterakhir.webp": "b03c134cb87706acc63ea56f435d8e2e",
"assets/assets/kartu/ItemProDay/cerminkecil.webp": "d41b2f393621801733ecddbdad600ebc",
"assets/assets/kartu/ItemProDay/jerikenembun.webp": "a3fbda8335c7508f9f297a6af29b3584",
"assets/assets/kartu/ItemProDay/keranjangbaru.webp": "4ff5c59e71cf34e23bdbfacc2e4f53ea",
"assets/assets/kartu/ItemProDay/perisaituduhan.webp": "246a4df371bbac1fdc8bef0d202502d2",
"assets/assets/kartu/ItemProDay/perlindunganmalam.webp": "fa5da953e56f70d1cde9907c61416ec3",
"assets/assets/kartu/ItemProDay/topleshati.webp": "6a2147e7143f8665020d08483e3f326a",
"assets/assets/kartu/ItemProRegenerasi/gen-abmix.webp": "c9149fe4120131127cbc54fc267571c1",
"assets/assets/kartu/ItemProRegenerasi/gen-bacillusthuringiensis.webp": "7803beec5dccd48270c744716b924081",
"assets/assets/kartu/ItemProRegenerasi/gen-bibitlab.webp": "d429c7487f60e0eb0dc2c2be124f06ef",
"assets/assets/kartu/ItemProRegenerasi/gen-biofortifikasi.webp": "2f3e0c75a0a1094a2c77218469c386a3",
"assets/assets/kartu/ItemProRegenerasi/gen-dronepengusirhama.webp": "83282342f235801968e6e7c2b4702a6b",
"assets/assets/kartu/ItemProRegenerasi/gen-dronepenyiramtanaman.webp": "c0dc4b6a61e7ef3c418f73c56c3689f8",
"assets/assets/kartu/ItemProRegenerasi/gen-genomediting.webp": "147418399d134d2a8713000bcf7bc882",
"assets/assets/kartu/ItemProRegenerasi/gen-lacticacid.webp": "aec6ea5c198fd4494f26219b4294661f",
"assets/assets/kartu/ItemProRegenerasi/gen-mediakultur.webp": "aa1c6fb0b39473f3537f501dced90c0a",
"assets/assets/kartu/ItemProRegenerasi/gen-poinregenerasi.webp": "3e9e06f44f996f6d93509f07d142c365",
"assets/assets/kartu/ItemProRegenerasi/gen-poinregenerasi2.webp": "54e25b9070ac9af6bed496dcfb27e1b4",
"assets/assets/kartu/ItemProRegenerasi/gen-poinregenerasi3.webp": "af3fe123b5029c3e91353c32623a179b",
"assets/assets/kartu/ItemProRegenerasi/gen-pupukeco.webp": "4b3ce68514b64df1d1ae72cbea65c456",
"assets/assets/kartu/ItemProRegenerasi/gen-semprotannanokarier.webp": "4e60793b1129e3bab14c01ff37862025",
"assets/assets/kartu/ItemProRegenerasi/gen-soilmoistureprobe.webp": "47ed2fc7d8d078bb037f2c45cfdc47ac",
"assets/assets/kartu/punggungkartu/punggungantagonis.webp": "57ae2dd4ccd557b2d68ac186d35c0b64",
"assets/assets/kartu/punggungkartu/punggungitemantagonis.webp": "57ae2dd4ccd557b2d68ac186d35c0b64",
"assets/assets/kartu/punggungkartu/punggungitemantarekayasa.webp": "ac269383a3d7650a90d038cd124f7657",
"assets/assets/kartu/punggungkartu/punggungitemmalam.webp": "2659aa582be21e8258cb5d82bee3f467",
"assets/assets/kartu/punggungkartu/punggungitemproregenerasi.webp": "3b28a8d58cde369b0f8b29b8fc8c85e0",
"assets/assets/kartu/punggungkartu/punggungitemprotagonis.webp": "7555a7bdf6be05249e900ff75c411d31",
"assets/assets/kartu/punggungkartu/punggungitemsiang.webp": "46a095fec4f2eb35fe858a9abd96ed51",
"assets/assets/kartu/punggungkartu/punggungkemampuan.webp": "0a22373396e9fa2434e01c359b90adf7",
"assets/assets/kartu/punggungkartu/punggungprotagonis.webp": "7555a7bdf6be05249e900ff75c411d31",
"assets/assets/logo/ikon-transparent.webp": "06fa9cbecacc6388b597e86692f539d1",
"assets/assets/logo/ikonapp-transparent.webp": "21d7710de6b473107c3376fe3a48a797",
"assets/assets/logo/logo-linguistichegemony.webp": "eef27a634cb64fedc8a9573c9e9131d4",
"assets/assets/logo/logo-sampahnya.webp": "a82df3f853771fae4cf80299ade0c53b",
"assets/assets/logo/logoteks-transparent.webp": "9849ae3fe81df3c6374be589eb4ec3af",
"assets/assets/pohon/DRAFTpohongerak0.mp4": "65ef12026946455360bc6b736105fac6",
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
"assets/assets/sound/1.selamatdatang.mp3": "e1ae793b548c0c32d7eb829921991f9e",
"assets/assets/sound/10.malampersembahan.mp3": "c9fea49bce7b3f8298764d82f4c13c46",
"assets/assets/sound/11.musyawarah.mp3": "a651b97ec844d7dfdbd56c5c24a2c21f",
"assets/assets/sound/12.nyawa.mp3": "8db29806bb6bee998e424c86379757d3",
"assets/assets/sound/13.akhirkemenangan.mp3": "d1b088cfccbe543634151efcccdd23fa",
"assets/assets/sound/2.peranwarga.mp3": "67223ccb4a6b2afd46f3324e64a7e6cc",
"assets/assets/sound/4.embun.mp3": "8e555681a37204704573b5f5f460ab45",
"assets/assets/sound/5.pagiberbelanja.mp3": "af988b53be5097e27eb4e4c1c8dd795f",
"assets/assets/sound/7.kartukombinasi.mp3": "938d26b75addbb0fb6cea18ab04f2cf5",
"assets/assets/sound/8.informasikartupalsu.mp3": "8d912319d043b9db3e23b028922d9427",
"assets/assets/sound/9.seranganmalam.mp3": "188ae28e9aad1fed3c4cf147453a8d9f",
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
"assets/fonts/MaterialIcons-Regular.otf": "ece7645945a24211d47917f3656b9168",
"assets/NOTICES": "86517c9c5ef13527f72af833c9d67c12",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/atmosphere.frag": "307d9eabb754625428c7d4d8bb7e8bc8",
"assets/shaders/card_morph.frag": "87a70bf9d6bbb82535dfc51c440fab12",
"assets/shaders/cloth.frag": "191dcc44ed89406f8ba6267525bb98e0",
"assets/shaders/divine.frag": "1df92c3ac40f5d583a4a1491b4bb35a1",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/omen_sky.frag": "d775682af63b4d82fb42a94c36c06323",
"assets/shaders/prologue_fx.frag": "6b757542d5b571cc693bdf42506f9a4b",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/vote_reveal.frag": "fd7d3387f05ecf52d2a278f8e3ad5389",
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
"favicon.png": "0742d0803f670a0f1ef990cf152b0e0f",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "410cc43dc7cfcacb710dd64b255d070a",
"icons/Icon-192.png": "d479d025ecacf97923293737abd4c435",
"icons/Icon-192.webp": "21d7710de6b473107c3376fe3a48a797",
"icons/Icon-512.png": "53f9c8eff82ac247e3a4bc76a6a3188e",
"icons/Icon-512.webp": "21d7710de6b473107c3376fe3a48a797",
"icons/Icon-maskable-192.png": "d479d025ecacf97923293737abd4c435",
"icons/Icon-maskable-192.webp": "21d7710de6b473107c3376fe3a48a797",
"icons/Icon-maskable-512.png": "53f9c8eff82ac247e3a4bc76a6a3188e",
"icons/Icon-maskable-512.webp": "21d7710de6b473107c3376fe3a48a797",
"index.html": "e8810c49a8158ad25b7df982a3df3ea5",
"/": "e8810c49a8158ad25b7df982a3df3ea5",
"main.dart.js": "6b13ebeb0f4c8820a85dcc87d746c5b8",
"manifest.json": "996f2fe6e397924bc750171007628e80",
"version.json": "0027c1d613c5c157c36770d6df7a9ee4",
"_headers": "37cb9ac50993ed26a84190a1031c15c3"};
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
