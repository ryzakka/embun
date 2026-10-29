'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "1273961eb476158e8371a87c30bda72d",
"assets/AssetManifest.bin.json": "c2662ec4a7cd16f764f173f75df8e8a7",
"assets/assets/bentang/desajembatan-kering.webp": "867d4e8dfd360f30f67d6100fc199d9f",
"assets/assets/bentang/desajembatan-keringgulita.webp": "1837c9efac64ae6e27e37c42484f3148",
"assets/assets/bentang/keterasingan.png": "6a15a0e84002a459d4180aa37fe69a80",
"assets/assets/bentang/ladang-gersang.png": "c2b5e56523936ae38336d92356a1967d",
"assets/assets/bentang/lembah-hijau0.webp": "01bc0854745fd8265063d4e38cf5dc80",
"assets/assets/bentang/lembah-hijau1.webp": "ce1e854a2a3e22f58e59d2321aee7a8e",
"assets/assets/bentang/lembah-hijau2.webp": "bcdec857c2a94e8a4b311306b00786de",
"assets/assets/bentang/lembah-hijau3.webp": "9723619de85094a101cabbe0b7c55f98",
"assets/assets/bentang/lembah-hijau4.webp": "5ebdcf63840142bf4af5eafd187d993a",
"assets/assets/bentang/lembah-hijau5.webp": "9fea54870f1270847218e7b67896a9d5",
"assets/assets/bentang/pohon-zoom.webp": "2fd7b4b702bad09165522c186f3ac4a9",
"assets/assets/bentang/rumahdesa-gersang.webp": "25e01c63ab0de2503256006a11a88c8e",
"assets/assets/bentang/rumahdesa-hijau.webp": "7123a012b194dffd0539de4de97a40fc",
"assets/assets/bentang/rumahdesa2-gersang.png": "9e880f332879783339aabd8be004aa38",
"assets/assets/bentang/tertunjuk.png": "9252816677ce910c44bafc8e14038620",
"assets/assets/ikon/alert.png": "1f3ce9cc662ccdcda651a2e46456ced6",
"assets/assets/ikon/announcement.png": "03aab79106d72a54d72e5021ad239bc7",
"assets/assets/ikon/back.png": "fde9c6b663417ca1012f96605bab16c5",
"assets/assets/ikon/barter.png": "8254bf542e27daf2a0fe450dce8d2208",
"assets/assets/ikon/bubarkan.png": "6280baf9b2ba7ed8cdbf2bedd91dd37b",
"assets/assets/ikon/bulirembun.png": "7986188a90d01df0e159113e276e5880",
"assets/assets/ikon/bulirhitam.png": "013737ad2dc8e54ad891606127e740c9",
"assets/assets/ikon/centang.png": "1d988b145010de9faebfa97e14a6a010",
"assets/assets/ikon/change.png": "a6e3e36f39f0a305befa26b58dfc04be",
"assets/assets/ikon/character.png": "1186dd9f8a54d1ece6ac423f6fd45163",
"assets/assets/ikon/customization.png": "8d8c11d8737483df75be06da5e3f2236",
"assets/assets/ikon/danger.png": "1f3ce9cc662ccdcda651a2e46456ced6",
"assets/assets/ikon/dibeli.png": "583078389f0b51b5eabb59aa19775f45",
"assets/assets/ikon/dipilih.png": "2a415f8a8b5c9785de856a380baca226",
"assets/assets/ikon/discuss.png": "441c742bd8e901464819e57e82f375b9",
"assets/assets/ikon/donations.png": "129523dd7b82fb3eae5d264b59a69371",
"assets/assets/ikon/endday.png": "e3102dfc377e3fab7c6eb280ec737df6",
"assets/assets/ikon/hari.png": "62609419f1f77b97d9c713976dbdf1b3",
"assets/assets/ikon/helaidaun.png": "a8ca59f9022d78079307f2693ae46adf",
"assets/assets/ikon/hide.png": "4744c277242cf759bc79583ff5d4e698",
"assets/assets/ikon/home.png": "5f1f20d63d95f1c592ec8ad556222cff",
"assets/assets/ikon/host.png": "5fb6c703e7a395341301c79238987336",
"assets/assets/ikon/identity.png": "37038ce46e3f7c24d4b81963b034ca80",
"assets/assets/ikon/info.png": "2929bb1ab9d1cc88a455fb1bae564d35",
"assets/assets/ikon/item.png": "88f6bef8e68769b2752a7a811829dac8",
"assets/assets/ikon/joinroom.png": "9dca7fb5c41c8bd7dee025db9a4a3c0f",
"assets/assets/ikon/keluar.png": "ca3e80e4c1f995de4369641ca9486a36",
"assets/assets/ikon/kirim.png": "82845b723cceefe3dc6c18cf3b0fd568",
"assets/assets/ikon/lock.png": "624a9656aaca7a56482db48a0e8c75b1",
"assets/assets/ikon/logorhistory.png": "278a2ed2f50d3a98c968661c16533756",
"assets/assets/ikon/menu.png": "947971241d4db1edbefeca76ecf30213",
"assets/assets/ikon/minus.png": "a560a1679a98a7c3cd9da62ad8ef4a0d",
"assets/assets/ikon/mydeck.png": "cd547a56709bf1291ec77b7e3cd3be90",
"assets/assets/ikon/mydeck2.png": "95d1f4451d1e074ed28f1f696d9977cd",
"assets/assets/ikon/persona.png": "35308d723475546e9f7a51bc44864789",
"assets/assets/ikon/plus.png": "4abd22f318e855af1ffe546ab7409d19",
"assets/assets/ikon/poinmin1.png": "d18def5eccacb1fbde77e6daf3d2b583",
"assets/assets/ikon/poinplus1.png": "67a945189ba7dceafe0c7814c14b5d73",
"assets/assets/ikon/question.png": "fcdca01ff0d9c3a4c6dac728894581c3",
"assets/assets/ikon/refresh.png": "a6e3e36f39f0a305befa26b58dfc04be",
"assets/assets/ikon/roomcode.png": "d368f104ffd29c847dba7260b9a234b8",
"assets/assets/ikon/roomcreate.png": "5f1f20d63d95f1c592ec8ad556222cff",
"assets/assets/ikon/salin.png": "0e1a92c65fe3ea6db7b4e23f9df2212a",
"assets/assets/ikon/settings.png": "8d8c11d8737483df75be06da5e3f2236",
"assets/assets/ikon/show.png": "324700581e6d243c9a828903022c8295",
"assets/assets/ikon/showaddgraphic.png": "4f50215c7f96cccd1e4331bd1657730c",
"assets/assets/ikon/silang.png": "cb6a0b813eaf507abefa95c5e9edefd3",
"assets/assets/ikon/simpan.png": "548d4f9d5f45a1867ab56f71a514dc8f",
"assets/assets/ikon/skip.png": "68da695daa5909c6963873682b6dd09c",
"assets/assets/ikon/skip2.png": "84b9068d497a56ab4d78187944051457",
"assets/assets/ikon/start.png": "d159753d628478039361c93f9c5fe2b6",
"assets/assets/ikon/store.png": "db2ddd2478f1e74f7330e619dfbb3c3a",
"assets/assets/ikon/tertuduh.png": "dca681c85ad0d5034fde47dd03ec68e7",
"assets/assets/ikon/timer.png": "5819bf7d2ebccf3f3422aab17ec488ec",
"assets/assets/ikon/titlepersembahan.png": "2cc70d347f23038ee0dfd5bf94f1e566",
"assets/assets/ikon/touch.png": "729f487b1ed4e6bbd7eb64a21b98d5ff",
"assets/assets/ikon/vote.png": "8075820780980189fc44d79b905ab7b4",
"assets/assets/ikon/wait.png": "1516084aed83ef17132e99b2550c2151",
"assets/assets/ikon/x.png": "7e34f60c46f57c609cd554887b196083",
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
"assets/assets/kartu/poweranta/bisikan.png": "3f6a6267e5ae20cafce3adcc1fa8fbc9",
"assets/assets/kartu/poweranta/bonekasawah.png": "ee1e3bfae4416d9ed38ac812100dd5f1",
"assets/assets/kartu/poweranta/cangkul.png": "11bad71c9e0182a2cc81b6623072a027",
"assets/assets/kartu/poweranta/cermintakhayul.png": "65e03bc71425751ef0f7e31673d65d24",
"assets/assets/kartu/poweranta/gergajimesin.png": "1e4921e03edff665e1a74d4daecae7c2",
"assets/assets/kartu/poweranta/jaringhitam.png": "5a07fa3c25bfba4251257a7534598238",
"assets/assets/kartu/poweranta/kacapembesar.png": "3d6173766ff4f6580f3065455cec92ff",
"assets/assets/kartu/poweranta/kainnoda.png": "648698eead8bc16366769bdb1467c700",
"assets/assets/kartu/poweranta/kapak.png": "69ad126e970ed6f796a7075fa1031dbe",
"assets/assets/kartu/poweranta/kawatberduri.png": "70dd545ebfe63304876377dbb97824bc",
"assets/assets/kartu/poweranta/maskerudaraterkontaminasi.png": "c4ee4e57168086499b21bb7616224d3a",
"assets/assets/kartu/poweranta/menunjuktarget.png": "1512d89f74f67739b9a1e0a7f26cd3e1",
"assets/assets/kartu/poweranta/pakcairanasam.png": "04a979e9cd7bc22a7fa13b84f6146644",
"assets/assets/kartu/poweranta/pakpupukberacun.png": "b93c50a6920577fe92843edc0358d253",
"assets/assets/kartu/poweranta/papanpenanda.png": "369d103fc0ef3f6ef2645c732d252ed0",
"assets/assets/kartu/poweranta/penutupmata.png": "5acc7b04c3f93ec3c8246a7b48cb0a9d",
"assets/assets/kartu/poweranta/seemberairtoksik.png": "ed2e040ce663d891bf44f06c5e8e9415",
"assets/assets/kartu/poweranta/seemberbulirhitam.png": "7676f393d2217d6bf9e71e54008b5635",
"assets/assets/kartu/poweranta/segelasbulirhitam.png": "55d4c73b4662b855175f08abe396a2bf",
"assets/assets/kartu/poweranta/segelasbulirhitamtersaring.png": "b88d61dd8b60de6d510999ddf3a35b6d",
"assets/assets/kartu/poweranta/segenggambulirhitam.png": "04fdcc870ebc0299b61a4295e1069ab0",
"assets/assets/kartu/poweranta/sehelaibuluangsahitam.png": "4190a5fbc138d8e9dc5b9eb15195cb8e",
"assets/assets/kartu/poweranta/semprotanracunvegetasi.png": "664afd7523e47310934e59a4a13d97c2",
"assets/assets/kartu/poweranta/setopleskainkontaminasi.png": "8913c7e72cf182cbc365e35491b1371d",
"assets/assets/kartu/poweranta/setoplesserangga.png": "f96a9b3589b848b2e6660cfacf4e77c7",
"assets/assets/kartu/poweranta/suntikanvaksinnegatif.png": "3e7d949511cd336ddc042b6aea60b8f8",
"assets/assets/kartu/poweranta/talitambang.png": "b2c8b4bee47e994adc7313709077c113",
"assets/assets/kartu/poweranta/tanahberacun.png": "40249140a65a8e4c402a9be980e87b77",
"assets/assets/kartu/poweranta/topengpenarigelap.png": "fe0ac168a22735fbc8006aa3569de2e1",
"assets/assets/kartu/poweranta/topinoda.png": "afd629586de541c0c519e578e6a42fd7",
"assets/assets/kartu/powerpro/airsuci.png": "6dd25a6a589cd5b438ff180c7f53dcbb",
"assets/assets/kartu/powerpro/daunembun.png": "fa1c22b61d1944c00816781f8a85ca8e",
"assets/assets/kartu/powerpro/doabersama.png": "68bb984996dbcd2c4b66f58026c5adce",
"assets/assets/kartu/powerpro/duaikatbungamatahari.png": "14af9383c77442818d689c7d5eb4fee4",
"assets/assets/kartu/powerpro/emberair.png": "4f4cf211d4bf33072305e1b1bf9240f8",
"assets/assets/kartu/powerpro/esbatukotak.png": "e9adec3b0411247360b6f234d8d10562",
"assets/assets/kartu/powerpro/gelasembun.png": "1b988fd14ad841fb203bef5932db3070",
"assets/assets/kartu/powerpro/guntingrumput.png": "3d8a6bbd742586314cfd834ea25306dc",
"assets/assets/kartu/powerpro/kacapembesar.png": "58775a4ac25929eabc2081850987850a",
"assets/assets/kartu/powerpro/kainkotakhijau.png": "e8fefb8536bd4fc4bd860c99d3b87490",
"assets/assets/kartu/powerpro/kapalkertas.png": "b1849751853c01c35de30382e289ef54",
"assets/assets/kartu/powerpro/kayubakar.png": "68097a98270013b7a8ca4b9670631982",
"assets/assets/kartu/powerpro/kayupagar.png": "322563eb51cbf189e55a010b3d51d0c1",
"assets/assets/kartu/powerpro/kotakmedis.png": "3858e19117a5ef517759978e1441233a",
"assets/assets/kartu/powerpro/lampusenter.png": "d8c2a05877ce3cf2fdfe1b89474f8123",
"assets/assets/kartu/powerpro/lemparanasa.png": "0d6b6ce1df47ee075cb06122b670aaff",
"assets/assets/kartu/powerpro/lenteralawas.png": "b928de7a0cbb98efde6ec4876e6639c8",
"assets/assets/kartu/powerpro/lilinharapan.png": "88a8b621c5ba6af28736b88849c0d53f",
"assets/assets/kartu/powerpro/pakcacingtanah.png": "f0addfe2f2e945ee984bf7082f5c1727",
"assets/assets/kartu/powerpro/pakdaunkering.png": "6d6f5aa09bfd7358142d5d15841f767e",
"assets/assets/kartu/powerpro/penyiramtanaman.png": "dc53ff3638762458469ad9fe220df1a0",
"assets/assets/kartu/powerpro/pupukcair.png": "d461f34fe70ab8eaa29aa2f42de82c4b",
"assets/assets/kartu/powerpro/pupukdaun.png": "af724f57c333492d6ea4ea4d0e8961d0",
"assets/assets/kartu/powerpro/sekoptanah.png": "7ac241769c4ab9da1032ae9f28d051ea",
"assets/assets/kartu/powerpro/semangkukmelati.png": "22607741c1420e1ca6ecc2593e3be332",
"assets/assets/kartu/powerpro/sinarimitasi.png": "7fe2cb234925ec44598d619366b27c3d",
"assets/assets/kartu/powerpro/stetoskop.png": "67db650e924ea24fd240474dc09c96cc",
"assets/assets/kartu/powerpro/suntikanvaksin.png": "f0d75078a105426d172c6f43996842d3",
"assets/assets/kartu/powerpro/topengtari.png": "3819ff0c6ea6cadb6f2c7648e6b4412e",
"assets/assets/kartu/powerpro/topleskunang.png": "66965ffa4bacf280debf2f5191a9ade0",
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
"assets/assets/kartu/punggungkartu/Kunci%2520Astral%2520dalam%2520Kristal%2520Biru.png": "8183000320a44d78834ad80bc4f62d08",
"assets/assets/kartu/punggungkartu/punggungantagonis.png": "4c80ac4b37b81ad403647632c71205e6",
"assets/assets/kartu/punggungkartu/punggungprotagonis.png": "10ee19a36be12f094cc9254d772ed308",
"assets/assets/logo/ikon-transparent.png": "f5e0a8342591e2e562f32d9587573020",
"assets/assets/logo/ikonapp-transparent.png": "67f4157b8885c7c010604d94a25378f1",
"assets/assets/logo/logo-linguistichegemony.png": "678f9e984676928084092bfa5e2465b7",
"assets/assets/logo/logo-sampahnya.png": "5ee805e72aa2fa0dd552b0c7e236de0c",
"assets/assets/logo/logoteks-transparent.png": "7dd8bcf30cf259ca818fa76b7821342b",
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
"assets/fonts/MaterialIcons-Regular.otf": "138bac17b083d8a70c67b9e7bea6e236",
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
"flutter_bootstrap.js": "72379dffed74c89e645ffa3ddd698a77",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "de5cd924341a6010f14615fdbbbc0952",
"/": "de5cd924341a6010f14615fdbbbc0952",
"main.dart.js": "464a707d6767266ef2334cd93907ef85",
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
