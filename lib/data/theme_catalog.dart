import 'manhwa_catalog.dart';
export 'manhwa_catalog.dart';

const tiongkokTheme = 'lukisan_tiongkok';
const tiongkokDir = 'assets/kartu/Char/CharPro/CharProLukisanTiongkok';
bool isDraftTheme(String? theme) => theme == manhwaTheme || theme == tiongkokTheme;
String characterThemeLabel(String? theme) => switch (theme) {
  manhwaTheme => 'Manhwa Style',
  tiongkokTheme => 'Lukisan Tiongkok',
  _ => 'Default',
};

// ID ASCII stabil untuk jaringan; nama berkas asli tetap dipertahankan.
const tiongkokNames = <String, String>{
  'cn-jiuweihu': 'Jiu Wei Hu',
  'cn-erlangshen': 'Erlang Shen',
  'cn-boya': 'Bo Ya',
  'cn-guanyu': 'Guan Yu',
  'cn-lubu': 'Lu Bu',
  'cn-ludongbin': 'Lu Dongbin',
  'cn-nezha': 'Nezha',
  'cn-change': 'Chang’e',
  'cn-sunwukong': 'Sun Wukong',
  'cn-yuefei': 'Yue Fei',
  'cn-zhangchangzong': 'Zhang Changzong',
  'cn-zhangyizhi': 'Zhang Yizhi',
  'cn-zhuque': 'Zhu Que',
  'cn-libai': 'Li Bai',
  'cn-yangguifei': 'Yang Guifei',
  'cn-xuanwu': 'Xuan Wu',
  'cn-wangxizhi': 'Wang Xizhi',
  'cn-baihu': 'Bai Hu',
  'cn-huamulan': 'Hua Mulan',
  'cn-dongxian': 'Dong Xian',
  'cn-guanyin': 'Guan Yin',
  'cn-zhugeliang': 'Zhuge Liang',
  'cn-diaochan': 'Diao Chan',
  'cn-zhaoyun': 'Zhao Yun',
  'cn-zhongkui': 'Zhong Kui',
  'cn-qinglong': 'Qing Long',
  'cn-qilin': 'Qi Lin',
};
const tiongkokArt = <String, String>{
  'cn-jiuweihu-utama': '九尾狐',
  'cn-erlangshen-utama': '二郎神',
  'cn-boya-utama': '伯牙',
  'cn-guanyu-utama': '关羽',
  'cn-lubu-utama': '吕布',
  'cn-ludongbin-utama': '吕洞宾',
  'cn-nezha-utama': '哪吒',
  'cn-change-utama': '嫦娥',
  'cn-sunwukong-utama': '孙悟空',
  'cn-yuefei-utama': '岳飞',
  'cn-zhangchangzong-utama': '张昌宗',
  'cn-zhangyizhi-utama': '张易之',
  'cn-zhuque-utama': '朱雀',
  'cn-libai-utama': '李白',
  'cn-yangguifei-utama': '杨贵妃',
  'cn-xuanwu-utama': '玄武',
  'cn-wangxizhi-utama': '王羲之',
  'cn-baihu-utama': '白虎',
  'cn-huamulan-utama': '花木兰',
  'cn-dongxian-utama': '董贤',
  'cn-guanyin-utama': '观音',
  'cn-zhugeliang-utama': '诸葛亮',
  'cn-diaochan-utama': '貂蝉',
  'cn-zhaoyun-utama': '赵云',
  'cn-zhongkui-utama': '钟馗',
  'cn-qinglong-utama': '青龙',
  'cn-qilin-utama': '麒麟',
};
final tiongkokOutfits = <String, ManhwaOutfit>{
  'cn-jiuweihu-utama': const ManhwaOutfit('cn-jiuweihu-utama', 'cn-jiuweihu', 'Penampilan utama'),
  'cn-erlangshen-utama': const ManhwaOutfit('cn-erlangshen-utama', 'cn-erlangshen', 'Penampilan utama'),
  'cn-boya-utama': const ManhwaOutfit('cn-boya-utama', 'cn-boya', 'Penampilan utama'),
  'cn-guanyu-utama': const ManhwaOutfit('cn-guanyu-utama', 'cn-guanyu', 'Penampilan utama'),
  'cn-lubu-utama': const ManhwaOutfit('cn-lubu-utama', 'cn-lubu', 'Penampilan utama'),
  'cn-ludongbin-utama': const ManhwaOutfit('cn-ludongbin-utama', 'cn-ludongbin', 'Penampilan utama'),
  'cn-nezha-utama': const ManhwaOutfit('cn-nezha-utama', 'cn-nezha', 'Penampilan utama'),
  'cn-change-utama': const ManhwaOutfit('cn-change-utama', 'cn-change', 'Penampilan utama'),
  'cn-sunwukong-utama': const ManhwaOutfit('cn-sunwukong-utama', 'cn-sunwukong', 'Penampilan utama'),
  'cn-yuefei-utama': const ManhwaOutfit('cn-yuefei-utama', 'cn-yuefei', 'Penampilan utama'),
  'cn-zhangchangzong-utama': const ManhwaOutfit('cn-zhangchangzong-utama', 'cn-zhangchangzong', 'Penampilan utama'),
  'cn-zhangyizhi-utama': const ManhwaOutfit('cn-zhangyizhi-utama', 'cn-zhangyizhi', 'Penampilan utama'),
  'cn-zhuque-utama': const ManhwaOutfit('cn-zhuque-utama', 'cn-zhuque', 'Penampilan utama'),
  'cn-libai-utama': const ManhwaOutfit('cn-libai-utama', 'cn-libai', 'Penampilan utama'),
  'cn-yangguifei-utama': const ManhwaOutfit('cn-yangguifei-utama', 'cn-yangguifei', 'Penampilan utama'),
  'cn-xuanwu-utama': const ManhwaOutfit('cn-xuanwu-utama', 'cn-xuanwu', 'Penampilan utama'),
  'cn-wangxizhi-utama': const ManhwaOutfit('cn-wangxizhi-utama', 'cn-wangxizhi', 'Penampilan utama'),
  'cn-baihu-utama': const ManhwaOutfit('cn-baihu-utama', 'cn-baihu', 'Penampilan utama'),
  'cn-huamulan-utama': const ManhwaOutfit('cn-huamulan-utama', 'cn-huamulan', 'Penampilan utama'),
  'cn-dongxian-utama': const ManhwaOutfit('cn-dongxian-utama', 'cn-dongxian', 'Penampilan utama'),
  'cn-guanyin-utama': const ManhwaOutfit('cn-guanyin-utama', 'cn-guanyin', 'Penampilan utama'),
  'cn-zhugeliang-utama': const ManhwaOutfit('cn-zhugeliang-utama', 'cn-zhugeliang', 'Penampilan utama'),
  'cn-diaochan-utama': const ManhwaOutfit('cn-diaochan-utama', 'cn-diaochan', 'Penampilan utama'),
  'cn-zhaoyun-utama': const ManhwaOutfit('cn-zhaoyun-utama', 'cn-zhaoyun', 'Penampilan utama'),
  'cn-zhongkui-utama': const ManhwaOutfit('cn-zhongkui-utama', 'cn-zhongkui', 'Penampilan utama'),
  'cn-qinglong-utama': const ManhwaOutfit('cn-qinglong-utama', 'cn-qinglong', 'Penampilan utama'),
  'cn-qilin-utama': const ManhwaOutfit('cn-qilin-utama', 'cn-qilin', 'Penampilan utama'),
};
Map<String, String> themeCharacterNames(String? theme) =>
    theme == tiongkokTheme ? tiongkokNames : manhwaNames;
Map<String, ManhwaOutfit> themeOutfits(String? theme) =>
    theme == tiongkokTheme ? tiongkokOutfits : manhwaOutfits;
String themePrimaryCard(String characterId) => '$characterId-utama';
