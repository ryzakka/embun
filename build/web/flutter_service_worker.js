'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "4281973f14b16e56219bba063b095d1b",
"assets/AssetManifest.bin.json": "48dd7f28bd0321ae6376a5a889755b90",
"assets/assets/bentang/alunalun-tiangberpita.webp": "250ce118405c1d83668adf39ad9a40ff",
"assets/assets/bentang/anyaman-gelap.webp": "5322aff6e036276cb3e8960a77599f9b",
"assets/assets/bentang/anyaman-rusak.webp": "21b76bbe9458a9952369cf8d1b451492",
"assets/assets/bentang/anyaman-temaram.webp": "7528bfbcd78de6ff8112927a54f9e9fe",
"assets/assets/bentang/anyaman-temarangabungkartu.webp": "37f19f60587002c7603eb2c97ce0df8b",
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
"assets/assets/bentang/kedai-karturiset.webp": "5dcd2013f754c54b7d1430deefba3d15",
"assets/assets/bentang/kedai-kartuwarga.webp": "31f138bd85f358bb11e1517a8871b312",
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
"assets/assets/bentang/newDesa-bentang1.webp": "2c08a66c42ae3de92ac32fefd8e0a1af",
"assets/assets/bentang/newDesa-bentang2.webp": "bdd6daf2e24d6d90b1e501e99d0990e5",
"assets/assets/bentang/newDesa-bentang3.webp": "bece615322b5a2839c75679a4939134a",
"assets/assets/bentang/newDesa-bentang4.webp": "7a64a47bd3fc8eedc9b1cad5f4f1e401",
"assets/assets/bentang/newDesa-bentang5.webp": "5e684e21f82120d95cd9fec837389e33",
"assets/assets/bentang/newDesa-bentang6.webp": "3ce1d9a2f07d051d21bb792c90a499d7",
"assets/assets/bentang/newDesa-bentang7.webp": "757b668eace92ef51ec9c628fc310dcb",
"assets/assets/bentang/pasar-sianghari.webp": "035015d998144f95bdbeb20da04ba201",
"assets/assets/bentang/perpustakaantua.webp": "b02ee8c873ad49f39cfcf2647af239f7",
"assets/assets/bentang/peternakan-sianghari.webp": "7d656476e9f503a4ce28725447ede0fc",
"assets/assets/bentang/pohon-keranjangbuah.webp": "98be8412b94f6e64a88f8922442bc2c0",
"assets/assets/bentang/pohon-toplesnyaladankunang.webp": "74657cb9c3497761fabc35681216547a",
"assets/assets/bentang/pohon-zoom.webp": "9954702e6db7c6c44ba557224fcd2425",
"assets/assets/bentang/pohon-zoomberkascahayanaik.webp": "e34e74f69a54e6ac134efb55b0c95dd3",
"assets/assets/bentang/pohonindikator-akar.webp": "4e2faed89876bc086d19f65737e84410",
"assets/assets/bentang/pohonindikator-batang.webp": "3fa023288e831abf56d3aabee71f1b41",
"assets/assets/bentang/pohonindikator-daun.webp": "ee9937a5f2eaa2a90503a6b36f8e7a95",
"assets/assets/bentang/pohonindikator-tanah.webp": "3af3fdd8dd818501fd3ebde9e5e21319",
"assets/assets/bentang/pohonindikator-view.webp": "7414b9efb07b53f6f3fa771f400d7209",
"assets/assets/bentang/pohonindikator-zoomakar.webp": "fb572cfe98a5ce2284eac3d1e501b972",
"assets/assets/bentang/pohonindikator-zoombatang.webp": "b0e6325a53a208866bafc697b369ca1e",
"assets/assets/bentang/pohonindikator-zoomdedaunan.webp": "0170181bcc9349ea88df3e009ff001b0",
"assets/assets/bentang/pohonindikator-zoomtanah.webp": "1c65c8f25db6ebdfb59c9089904ff772",
"assets/assets/bentang/rumah-malamdepanpintu.webp": "4d7c1c57f7fe2eea130f0bcfb5c678e8",
"assets/assets/bentang/rumahdesa-gersang.webp": "8007db6b889be43e59fc710e0896d7c2",
"assets/assets/bentang/rumahdesa-hijau.webp": "a003b0422fcc0b54c5be25017ee62c95",
"assets/assets/bentang/rumahdesa2-gersang.webp": "2b3ea72d5f231df82c48e7a1a57fc36b",
"assets/assets/bentang/sinarmataharikedalamrumah.webp": "8a6d34a824a02a69d2bdfc8016ca2185",
"assets/assets/bentang/sumur-gelapmalam.webp": "4ed12077df9099254b5df5ab1f3485f4",
"assets/assets/bentang/sumur-sianghari.webp": "203f2e7123019205c569f77ff67dd84d",
"assets/assets/bentang/tempat-balaitukar.webp": "8b85a5968aed3d9a59775acaa1046335",
"assets/assets/bentang/tempat-bengkel.webp": "f98dc0317cb360dad330cf2661da4c37",
"assets/assets/bentang/tempat-pondokperawatan.webp": "6b9c93dbddf90251211481bdedc09ff7",
"assets/assets/bentang/tempatdalam-balaitukar.webp": "d2faea79bd22e1a028f26c050fddb7ed",
"assets/assets/bentang/tempatdalam-bengkel.webp": "16ac04950158a2da8455304d16859adb",
"assets/assets/bentang/tempatdalam-pondokperawatan.webp": "29f131b642ddc7916db5e2b640cc3ad4",
"assets/assets/bentang/tepisungai-tanggaterjalsianghari.webp": "cf870b7aa97e27b7aa0f7fa460f738b3",
"assets/assets/bentang/tertunjuk.webp": "0dae13153d6fee16bcf8e08bd19520d6",
"assets/assets/ikon/addmember.webp": "47729f3106f84819a636fdecc21278c6",
"assets/assets/ikon/akhir-kalah.webp": "40126048a9f4ace274ddb1037e444e8e",
"assets/assets/ikon/akhir-menang.webp": "264c2bf3cbceb56f4b6dda766074c3ce",
"assets/assets/ikon/alert.webp": "5f3d41902945bed7bb5ebad5d0bf9b08",
"assets/assets/ikon/announcement.webp": "12c8cbdc9074c38accc50954cfe28d2d",
"assets/assets/ikon/back.webp": "e087d4988c7cbb0622cac929984118ba",
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
"assets/assets/ikon/title-musyawarah.webp": "eed158aedc979ab184703749bbd34fc6",
"assets/assets/ikon/title-pasarriset.webp": "ef1024c039b5c6395f8f0634f3dcf442",
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
"assets/assets/kartu/CharPopUp/popupchar-anta-bengkelkartu.webp": "6d4d6e180c2769edb8253f8b38f53829",
"assets/assets/kartu/CharPopUp/popupchar-anta-munculdariatas.webp": "3b3b4dc11446560e31bd91a896d66a4b",
"assets/assets/kartu/CharPopUp/popupchar-anta-pasarriset.webp": "d8847a7db02d5c0462c2ad6f87d28430",
"assets/assets/kartu/CharPopUp/popupchar-anta-perawatan.webp": "be58548d9a0f96c6d53c23c5650c991c",
"assets/assets/kartu/CharPopUp/popupchar-anta-sumur.webp": "14806c432a0142ed49283eac7335c084",
"assets/assets/kartu/CharPopUp/popupchar-pro-barterselesai.webp": "d847b70bb77c767b019d7b16e514fa17",
"assets/assets/kartu/CharPopUp/popupchar-pro-bartertanya.webp": "f97742e48d4ae51b0462577f8c8612cb",
"assets/assets/kartu/CharPopUp/popupchar-pro-bengkelkartuselesai.webp": "404e05abc2937b2e09859c807842e86d",
"assets/assets/kartu/CharPopUp/popupchar-pro-bengkelkartutanya.webp": "4ba503ae03fbc9be4ef3fbe6ad167ad0",
"assets/assets/kartu/CharPopUp/popupchar-pro-pasarrisetselesai.webp": "eed28371a2508cea3d31ef84dfe2270d",
"assets/assets/kartu/CharPopUp/popupchar-pro-pasarrisettanya.webp": "85749d7f113d4690a14a6e4c0e22c5f4",
"assets/assets/kartu/CharPopUp/popupchar-pro-perawatanperiksa.webp": "91c262014e026d761b4b08d5aa508038",
"assets/assets/kartu/CharPopUp/popupchar-pro-perawatanselesai.webp": "1b39b4e740d4c101bbe3c6090fc90efe",
"assets/assets/kartu/CharPopUp/popupchar-pro-perawatantanya.webp": "a4b949aeb5eb7b56fd1f15528e63fdfd",
"assets/assets/kartu/CharPopUp/popupchar-pro-sumurselesai.webp": "417ea6b24be36d1872db640317398add",
"assets/assets/kartu/CharPopUp/popupchar-pro-sumurtanya.webp": "ee305f9953a27227dd3e4e2478e45c7d",
"assets/assets/kartu/CharPopUp/popupchar-tutor-ayo.webp": "914652e85b893d265722e4c7103c594f",
"assets/assets/kartu/CharPopUp/popupchar-tutor-belanjakebanyakan.webp": "260e767bdff1ad12551bd72df7feedff",
"assets/assets/kartu/CharPopUp/popupchar-tutor-berfikir.webp": "6e7dffefc05710ace974fea32b750f1c",
"assets/assets/kartu/CharPopUp/popupchar-tutor-emberberatair.webp": "45ded44bf12c5dc4eadc8f05019a1680",
"assets/assets/kartu/CharPopUp/popupchar-tutor-gabungair.webp": "9fb48957781197205270b23e620576f2",
"assets/assets/kartu/CharPopUp/popupchar-tutor-kebingunganataukesal.webp": "37f99a48f3d9ee0cb53aeb9f36960b56",
"assets/assets/kartu/CharPopUp/popupchar-tutor-lesu.webp": "3a63b1f5ac8a78cc7b5b6bcd6614d839",
"assets/assets/kartu/CharPopUp/popupchar-tutor-menghitung.webp": "e222af2b04c9449c5fd3cbc9ffb4d666",
"assets/assets/kartu/CharPopUp/popupchar-tutor-menunjukmemilih.webp": "35fdfa9d0478f85cf396f306d8175b19",
"assets/assets/kartu/CharPopUp/popupchar-tutor-menyapa.webp": "24c8a40f5d0ccdfda5338b417d4887c0",
"assets/assets/kartu/CharPopUp/popupchar-tutor-panik.webp": "7e52b72562c072ebf8bf3c9a3ea3c6b1",
"assets/assets/kartu/CharPopUp/popupchar-tutor-persembahan.webp": "eaeb9a31ae438b79aa69079fcfc8cdab",
"assets/assets/kartu/CharPopUp/popupchar-tutor-tanya.webp": "1d30cd50a91a77d57acd109e3d9fdc64",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-ahlipijat.webp": "3cea817b452bba637ad3e0470cabee38",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-ahlisauna.webp": "873db759a9e21ebfb94cda3af606a20b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-arsiparis.webp": "64054a45a989f2dbd9bcf06293d27ba4",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-asistenperpustakaan.webp": "c7bb3de99fe1c6805e98307167c5087a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-dokter.webp": "03100d2b3a40bdaec8281c5e75439390",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-dokumentalis.webp": "2aa279a6d9821bf3f114ec3052818908",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-jurumasak.webp": "cd6f1a3582607c3757357b0dd148fb94",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-jurumasak2.webp": "f2a36e34d345d6112eb9ba2f35fa1b10",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-kesatria.webp": "6f22417037ede95c72f1e9b4d95ac885",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-matamata.webp": "9d660430fad451a07c9daf025dbf240a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-mediskolamrenang.webp": "bfc72f7988e8ba8ae5ed6a3d2baed27e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-medispantai.webp": "4664f568d1dc6f2e2d1c7f746e198157",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-medispantai2.webp": "e97a4379be8cb2149019dc74d5817da9",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-modellukis.webp": "226bd29520fb16ab916e1c80cddcf631",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-modellukis2.webp": "65c04614bb1a72e5547ab0bea5743841",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-modellukis3.webp": "08e12b1cabcccd00e258944e9187aa7c",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-modellukis4.webp": "a4b103441e236a83c59bfc2bfef007e6",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanbudidaya.webp": "74291abe6359ad985aa8111c93371595",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayandemersal.webp": "678d27b53c5f9e3117608c22b1f38d45",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayandemersal2.webp": "1fd10dc51e39ad8ce1c2275fc316acd9",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanpelagis.webp": "bd9ec8d7a606cb127be29b9f69b34ef4",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanpelagis2.webp": "70542f1d5d342233bdadad9f661b6833",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanpesisir.webp": "6e85814d78d5e266f63efdac7b6b89d7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayanplasma.webp": "c2adf744b810f53b38ec5910768e4f9d",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-nelayantambak.webp": "4b6794a18289a8f6f16f7d1cfb110adf",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-olahragawan.webp": "fa5de4de7776b04405de29f96b9d8aa7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelajarrenang.webp": "22bcd47b0bb3e58bf01b6df4656ed007",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelajarselam.webp": "b95d0d05e162c1ecd063dae4f1e98135",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihkebugaran.webp": "0aafa7cafe19bcd967c4b8426e2410b9",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihpanahan.webp": "7187a9f83f5c12b0334c99009f1c1e0e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihrenang.webp": "c060772964b3037178e738066ab05149",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihselam.webp": "6d17e830bacb6321581cddf6eeb9d422",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihselancar.webp": "477b4fcfd90816ebb7e778cf2113a7b3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihselancar2.webp": "feecebc97d1ee1f1ecd68cbe119a4175",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelatihstrategi.webp": "01c7d66bf0e22b65ea8cc56b5d1849f5",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pelindung.webp": "c96bce41a34e94c0bc89e0b36d0aaaa3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemanah.webp": "2c8688521ac36737c60ab77a578eacf3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembersihjalan.webp": "48890099594f8d4a1bfc16c968f6a303",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembersihpantai.webp": "e71f3294dc3fd49b4c02aa8582e51774",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayaikanhias.webp": "9e30f5c055f4f3b4a85d8471c2621671",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayamutiara.webp": "fc5d8e126937f56fb80879052b7c8908",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayamutiara2.webp": "d2c85db2e520228f1a48c60b7e9258dd",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayarumputlaut.webp": "d94f982689a253726afe3b10bc9ab748",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayarumputlaut2.webp": "fbcd811dae31874f0d34e452d401c49f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembudidayaudang.webp": "ef72c4d844f3bba880f71e2dc83f93c0",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemburu.webp": "a3b7479930a6e83d5d03d0c85b771129",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemburubabihutan.webp": "06fc6e543766f654909512fd03b5627a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pembururusa.webp": "82ee044fb13c5608068e046d35cc40ef",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemeriksamedis.webp": "fc15c3b104a2c203f5f7ee385b65289f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemetikbuah.webp": "be11321547d8e4664431e5ae9024f381",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pemetikbuah2.webp": "1c7368f94387a1460b0c97814f549657",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penambakgaram.webp": "2e443a947b46600daaf485fdd5109c24",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penambangbatubara.webp": "877be32083ea08461d09ee2950465a4c",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penari.webp": "ad8e88bf50e8a66310398445a1a0f09f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penarikerajaan.webp": "2c4baa1a79871e3a2a0c74ba4cbbf15a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penarimagis.webp": "4ad62c627f4f9b15bcb75e3ffad569c0",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penaritiang.webp": "681a84443aee7542cdf9b8525c16a5e7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penatarias.webp": "e1e9b3623a71bf3f885797863f40653f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penatu.webp": "dce236a34376be35076157656b15fe74",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penebangkayu.webp": "441a333a73571eaee7070d4714358c63",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggoda.webp": "1e37f03c05824e430ed7a55756bbad63",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggoda1.webp": "7c922833852f22316e703e9115cf2cb5",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggoda2.webp": "cfd7886f022e9118f5b9b8f1bffe7ecb",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penggoda3.webp": "dbab4fedad435070ebc96e3cc704f011",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagalaut.webp": "1a537d2fcce430c6e4954d456696b214",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagamenarajaga.webp": "06d83c835b97581317e5b2d52c3713ac",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagamercusuar.webp": "7dbf2d9f5f9344e4484aabbd676e6684",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagapantai.webp": "29877268d4f93fbf8f9ff53270a95b08",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagapatroli.webp": "a4d93c862a568deb53fd048ce252ae78",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagaperbatasan.webp": "1264b1661a34cc0a316a7f055d677426",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagaposjaga.webp": "90cc4914f9ad9128143da18336ea49df",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjagatokopantai.webp": "2a2eb3775aa42a50ba7fe6ed508312f3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penjelajah.webp": "a5032d5fbbf760fbf13dc45a975c0dbd",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapkaret.webp": "b847001ad0fe4654efab7eba8c7ce73a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapkaret2.webp": "c3b69c7e1dcc1fe26d2c8ca616c417f4",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapkaret3.webp": "fe09641c55fbcc6fbecdb41bc0edb88f",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapkaret4.webp": "af886d8d89f1849bde66b8fa9d6a0325",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapnira.webp": "3aa733eae4d1309a2ccd6480912f380b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyadapnira2.webp": "6243f4cce4bd0e68c6edd822b55a7d43",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyangraibijikakao.webp": "8ffb29a776e7f223aa18cc59a2ab7a20",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyangraibijikakao2.webp": "a09adc2b76863ce58b99345f86b9cacd",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyangraikopi.webp": "b562ee8af0df195fd4d223d05ad331f3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyelam.webp": "147dd6885ac5945d1dfc17f114581638",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-penyelamkeselamatan.webp": "7ba2c5a5eed07954ccce9de6f60e8791",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perakitkapal.webp": "fa0597d5002f625c1fd73ef0729e8f80",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perakitkapal2.webp": "6cfb7313928c9ef8b784485fdacb49be",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perakitsenjata.webp": "4ddcc0c2d9837c365c8f0cc496de914b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peramalcuaca.webp": "e8408ec1b3c656d3dc31f2020810927a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peramalnasib.webp": "4f0a32f80bed92a385c224e7c4d0e425",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peramujamur.webp": "aabf4a9439db622793c6d598ff6594f7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peramumadu.webp": "0bce759c362aa1f213592dc15489f4a7",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perancangkapal.webp": "23d999f20a9fa869165028bab5a2acd0",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perawat.webp": "f1349a7bcf25afa1b964fb9b7c50fbf9",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-perenang.webp": "9ca976c57c17452e2056317fbee9a9d6",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peselancar.webp": "60d8c254469db60c5eb2a447f194c729",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petambakgaram.webp": "ed431a26505c71ec3f7aa0ec45de8fc2",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanidesa.webp": "8ab9296e5268eb5770e97c83813b668b",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanihortikultura.webp": "83365f0733d34be1dd0009349e411df2",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanijagung.webp": "3a18f167993d344b7256a0b9796a06f1",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanikedelai.webp": "39c19855f0c6d4a242dcd5b3047d3ca4",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanikedelai2.webp": "7db4ae34b6a75a3d58253bcc48520418",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanipadi.webp": "41b72f142bb9d0dcaedb9e94db6b7eda",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanipadi2.webp": "bf27e72bcab7a8a34f7beb34aa313ac3",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petanipalawija.webp": "cd7edca875dde6c226e80dae67afb896",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakbibit.webp": "921d6cef57ab96ee92d0b40a602df472",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakbibit2.webp": "7a58d9feac27b4ea710ce280f3308743",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakpedaging.webp": "d518825088427f723a7abf23a01f1dde",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakperah.webp": "95f78df116c89399fff5ad77b1f3bf83",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternakperah2.webp": "df8a278aaf18e04c4c16223bb9542858",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-peternaktelur.webp": "a5b35266578342545ea4258db534f512",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-petuadesa.webp": "a74fe98a28087bd34934dc1e011e34e6",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pramusaji.webp": "2be4832e234f18f4f61347909cc2b27a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-pustakawan.webp": "6fc7c2fc322ab8a5856b5190c458c31e",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukang.webp": "d53f8fac111b8071e3f18058572c20f6",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukangdrainase.webp": "3cc65fb022d8153453755480a1522c19",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukanggerobak.webp": "fe6605f2fd5333390c36a94524c6f04a",
"assets/assets/kartu/CharPro/CharPro-Pria/pria-tukangmercusuar.webp": "2725a40110da684900a3162ac8e31f21",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-dokumentalis.webp": "602d9a88126ccb5811fca6660c98bca0",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-matamata.webp": "e2a0505154a72d8b4cde9dd6d64aefe5",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-modellukis.webp": "5db872ad3896af0607b9d25e8a77483d",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-nelayanbudidaya.webp": "c5a05006ed8cb68fc80d10659b836d34",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pemanah.webp": "f02fafdbe2e1b7aa8d15cc2e005e2c4f",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pemburu.webp": "c79b43b3fadf659775ac2bca9c2c4b57",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pemburu2.webp": "27a471d3ce99da5a44be85f21bf1fd20",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penari.webp": "3fa8d683f34dfc64e3fdae65f51a5d28",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penarikerajaan.webp": "5d0bffdd8d70e80c36181d9727949d04",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penarimagis.webp": "09b6f67c4c76603edf25f0f62020a3e4",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penatu.webp": "fa74f90d55cec6159724f35fce566628",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjagalaut.webp": "ff3f246a31f343901cd8799c279a3180",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjagamenarajaga.webp": "18144e15e5aa2b60c844a16c24a5ce8a",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penjelajah.webp": "4a07b7f12df97890199da6489fb665c3",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penyadapkaret.webp": "c546d9d59f10cd22cbfa094a3329e249",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penyangraibijikako.webp": "665d6b5f699ec8e5e62c56ecc8953a27",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-penyelam.webp": "2aaa97c48c46375e24f22041e01b4f36",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-perakitsenjata.webp": "846e9a34a7d9111c2d574628f54d8f1d",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-perenang.webp": "f6999ba5a9babeaba2e8c151a13ee5a3",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-peselancar.webp": "27578a9f54b58de2a48370dea591823c",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-petanipadi.webp": "bc74e9a2bdedbb9a72a91335efc66f18",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-peternaktelur.webp": "8e154f19a973253a2ccced31fbef20b8",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pramusaji.webp": "0d7b52dd16f61de3896c713b88804351",
"assets/assets/kartu/CharPro/CharPro-Wanita/wanita-pustakawan.webp": "2698e19dd99653088295cabb03794eb6",
"assets/assets/kartu/CharSkill/kemampuan1.webp": "e57bd1847a6fc129370c304ebe791cb2",
"assets/assets/kartu/CharSkill/kemampuan10.webp": "be3be672cbb57a84fc337c3ff9ae69cb",
"assets/assets/kartu/CharSkill/kemampuan11.webp": "58cb1ff6dfd4e645bf7c359c664af696",
"assets/assets/kartu/CharSkill/kemampuan12.webp": "5dfcabc45e94339e5d3db2d5c1abce7e",
"assets/assets/kartu/CharSkill/kemampuan13.webp": "80277c6061406c77c0c01ecb128545c1",
"assets/assets/kartu/CharSkill/kemampuan14.webp": "2fe015c5772850acbe599663627ba85e",
"assets/assets/kartu/CharSkill/kemampuan15.webp": "dfbf014c16d6caa258721f556577c334",
"assets/assets/kartu/CharSkill/kemampuan16.webp": "83db2b006472e1f4794aa162453b1bc2",
"assets/assets/kartu/CharSkill/kemampuan17.webp": "2fa4372d436bda0f237ad3d0ef44ac25",
"assets/assets/kartu/CharSkill/kemampuan2.webp": "1970322ef598b4a90fe205c607c67106",
"assets/assets/kartu/CharSkill/kemampuan3.webp": "53a0b87f1ada99e1bc0a1b24299c77d7",
"assets/assets/kartu/CharSkill/kemampuan4.webp": "376b18d72fe225c73c785ec5295cb69c",
"assets/assets/kartu/CharSkill/kemampuan5.webp": "531e40ff5f35181238c03e4d829bd4b6",
"assets/assets/kartu/CharSkill/kemampuan6.webp": "48a894a0945bf141d737af8383ba5c2b",
"assets/assets/kartu/CharSkill/kemampuan7.webp": "155336c9f7e998d8c3f096c657516ecd",
"assets/assets/kartu/CharSkill/kemampuan8.webp": "0f9d8fb21359b8067e859ad9f9690281",
"assets/assets/kartu/CharSkill/kemampuan9.webp": "578175e3ff4ee56b1fd626e86793e545",
"assets/assets/kartu/ItemAnta/asam-jerigen.webp": "6aa0bcdb6f7575ecf1d7d82eed30740f",
"assets/assets/kartu/ItemAnta/bisikan.webp": "d6aaa8e1a8b3648f13d1eda76defa15c",
"assets/assets/kartu/ItemAnta/boneka-sawah.webp": "51c8f9dd0abd97bfc46ff9869b64392b",
"assets/assets/kartu/ItemAnta/boneka-voodoo.webp": "4e5461bb68599f6b52275fb36af6bd64",
"assets/assets/kartu/ItemAnta/bulirhitam-drum.webp": "b677a9727c18098fbfaa01b36f7d1d3a",
"assets/assets/kartu/ItemAnta/bulirhitam-ember.webp": "810e3667cbbd26973410170b90ff3de1",
"assets/assets/kartu/ItemAnta/bulirhitam-emberbesar.webp": "546cda8bf9115baaf66e9a72bfa537e3",
"assets/assets/kartu/ItemAnta/bulirhitam-gelas.webp": "a902a62b18a958b13c178cd73dbeeb59",
"assets/assets/kartu/ItemAnta/cangkul.webp": "c343bde8d9ea3d9238cdf7b43af8526f",
"assets/assets/kartu/ItemAnta/gergaji-manual.webp": "da4458cc4ccd43de2a07180e6d6b453f",
"assets/assets/kartu/ItemAnta/gergaji-mesin.webp": "c31a47c9a3f3f874d0e6df69ea7c0aa4",
"assets/assets/kartu/ItemAnta/jahit-keranjangjahit.webp": "2cd42fce493169a4c1e45123d37f871b",
"assets/assets/kartu/ItemAnta/kapak.webp": "6c2aaeda3331f10754194b985ad002be",
"assets/assets/kartu/ItemAnta/kawatberduri.webp": "751dc51e1572d0d71d3797eb23226de7",
"assets/assets/kartu/ItemAnta/kontaminasi-kain.webp": "03d0553b2c2cf5871b609c8ac69037e9",
"assets/assets/kartu/ItemAnta/pengguntingrumput-mesin.webp": "5fda3bcc78f87809af9132d92659caab",
"assets/assets/kartu/ItemAnta/pupukpalsu-karung.webp": "b11e4a87d36a55a94218c2b5976a8ee0",
"assets/assets/kartu/ItemAnta/pupukpalsu-karungganda.webp": "ca02da8ba5eed2479462a723836885b0",
"assets/assets/kartu/ItemAnta/racun-drum.webp": "e98368610fee70a0beffcf551e01dce1",
"assets/assets/kartu/ItemAnta/racun-ember.webp": "d59716535ad730b27351786043087462",
"assets/assets/kartu/ItemAnta/racun-sekop.webp": "93522fcdb7e4989fd45fbaf6fbf9043f",
"assets/assets/kartu/ItemAnta/racun-semprotan.webp": "a94fd73ac0334ce682c49624793795ad",
"assets/assets/kartu/ItemAnta/racun-sudip.webp": "c02d5d7ea2c82bbf883ba378dc83db22",
"assets/assets/kartu/ItemAnta/racun-suntik.webp": "6dd58a22579a7aa5c97c9d258808caea",
"assets/assets/kartu/ItemAnta/ramuan-hitampeningkatan.webp": "e728443748729727b1a7fa87c8c2567c",
"assets/assets/kartu/ItemAnta/ramuan-ungumistispercepatan.webp": "b220988da98e7adce54411ca615ab484",
"assets/assets/kartu/ItemAnta/rayap-toples.webp": "194aeb5da481b158a3244323b3e53db0",
"assets/assets/kartu/ItemAnta/roti-surplus.webp": "45027cfb1f20972dd5e87d7c56c464ef",
"assets/assets/kartu/ItemAnta/ulatbulu-toples.webp": "62fae029fafe78511d574130a14a7884",
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
"assets/assets/kartu/itemPerawatan/anta-suratsakit.webp": "131100b79624c8a77836eeab4457b782",
"assets/assets/kartu/itemPerawatan/pro-suratdokter.webp": "fdd7261e8d286df5714d12b3afd09abc",
"assets/assets/kartu/ItemPro/airsuci.webp": "f21d80d6432fdda0cb76ef84449f7d34",
"assets/assets/kartu/ItemPro/daunembun.webp": "46f720fca5051c56b2d4614ad2d22fe4",
"assets/assets/kartu/ItemPro/doabersama.webp": "a6544cdae9843f63911a54a14b1d5516",
"assets/assets/kartu/ItemPro/duaikatbungamatahari.webp": "ea0010e5f85edef9b86b3b27d054fd6d",
"assets/assets/kartu/ItemPro/emberair.webp": "1d7e7b0db43e385372c726b80fc2c280",
"assets/assets/kartu/ItemPro/esbatukotak.webp": "1c7dfe8997513cded48a894ad9096d51",
"assets/assets/kartu/ItemPro/gelasembun.webp": "672740d2cecf1b802a1c326279213ea2",
"assets/assets/kartu/ItemPro/guntingrumput.webp": "2830674c4cc776de3e91e85f10a57602",
"assets/assets/kartu/ItemPro/ikanemas.webp": "c76f453a3800de57a785fe66ee304cba",
"assets/assets/kartu/ItemPro/kacapembesar.webp": "59d5afdf28f4c380d3690ce5b6b3de18",
"assets/assets/kartu/ItemPro/kainkotakhijau.webp": "56d9381efdd4a977acaa31b60c469529",
"assets/assets/kartu/ItemPro/kapalkertas.webp": "5decdf32c526cbb33cb75ef047f5187c",
"assets/assets/kartu/ItemPro/kayubakar.webp": "c60312cbb744dadac16e79dc7961a5d0",
"assets/assets/kartu/ItemPro/kayupagar.webp": "d78968181f9fb8e5af29b428e8debfbd",
"assets/assets/kartu/ItemPro/kotakmedis.webp": "f56810fd4eb6da9b9928402a40f2c5fa",
"assets/assets/kartu/ItemPro/lampusenter.webp": "02a096eb8d8aa4db5622c7673ca3609e",
"assets/assets/kartu/ItemPro/lemparanasa.webp": "30c59809dd5b7b6372c3af56063d2337",
"assets/assets/kartu/ItemPro/lenteralawas.webp": "a69d80af63afda579875cd75960e4739",
"assets/assets/kartu/ItemPro/lilinharapan.webp": "325e9e46bb7e521e80faf06e942f33df",
"assets/assets/kartu/ItemPro/pakcacingtanah.webp": "96e4ae904177f9c035a8d6112e0ebfe6",
"assets/assets/kartu/ItemPro/pakdaunkering.webp": "74ee85c33d67762e0ac765561b2b383b",
"assets/assets/kartu/ItemPro/penyiramtanaman.webp": "954022a63b230bc8b5302d5cc8159a26",
"assets/assets/kartu/ItemPro/pupukcair.webp": "07416f8460a5282671683f7b9de0060e",
"assets/assets/kartu/ItemPro/pupukdaun.webp": "9d146448c8ca437b807698b61193d77d",
"assets/assets/kartu/ItemPro/sekoptanah.webp": "ac591eb22c0c8f4bfab6cf4f4622d785",
"assets/assets/kartu/ItemPro/semangkukmelati.webp": "545329bfb0b67755b259a303a6b16ae6",
"assets/assets/kartu/ItemPro/sinarimitasi.webp": "62790edc40507d6907b2b8714fb7632f",
"assets/assets/kartu/ItemPro/stetoskop.webp": "937ad79beead19a871e34c0dd881c59b",
"assets/assets/kartu/ItemPro/suntikanvaksin.webp": "77de64a80cc772b397da211b2caae514",
"assets/assets/kartu/ItemPro/topengtari.webp": "660a03d7886a46ab56ad4034a3c143eb",
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
"assets/assets/sound/musikLatar-1.mp3": "57b61786b6efe9b8682c4dfb353be5bc",
"assets/assets/sound/musikLatar-2.mp3": "593c66f6150c8e5d62b8fa00b43d513c",
"assets/assets/sound/musikLatar-3.mp3": "add4165258445e1ece78b3b40665864e",
"assets/assets/sound/musikLatar-4.mp3": "e82554bf2c892eab74954ed7035bad84",
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
"assets/fonts/MaterialIcons-Regular.otf": "6b95ac8b72f4a1c6651df62d0a78cdb7",
"assets/NOTICES": "86517c9c5ef13527f72af833c9d67c12",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/atmosphere.frag": "307d9eabb754625428c7d4d8bb7e8bc8",
"assets/shaders/burn.frag": "c928e9f3bb26a66e1b27b6d2b7c2aa4a",
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
"flutter_bootstrap.js": "37ebf816b8286a8e81213329ac56d893",
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
"main.dart.js": "cb92e3f9b4de8b9e396740ea6a1ff828",
"manifest.json": "996f2fe6e397924bc750171007628e80",
"version.json": "0c2c27559c0bfd79046d10a3ff8b2335",
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
