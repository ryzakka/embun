import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/icon_catalog.dart';

/// Pemetaan berdasarkan arti. Panah kecil, pencarian, palu, kamera, dan
/// lambang teknis tanpa padanan gambar tetap memakai simbol yang tepat.
// IconData overrides equality, so its keys require a runtime map.
final Map<IconData, String> embunMaterialIcons = Map<IconData, String>.unmodifiable({
  Icons.arrow_back:'back2',
  Icons.volume_up_rounded:'suaranyala', Icons.volume_off_rounded:'suaramati',
  Icons.science_rounded:'botollab',
  Icons.nightlight_round:'bulansabit', Icons.nightlight_outlined:'bulansabit',
  Icons.nights_stay_outlined:'bulansabit', Icons.bedtime_rounded:'bulansabit',
  Icons.wb_sunny_outlined:'matahari',
  Icons.favorite_rounded:'hatipenuh', Icons.favorite_border_rounded:'hatikosong',
  Icons.heart_broken_rounded:'hatikosong',
  Icons.person_outline:'identity', Icons.person_outline_rounded:'identity',
  Icons.person_rounded:'persona', Icons.account_circle_outlined:'lihatprofil',
  Icons.person_remove_outlined:'hapusdata',
  Icons.workspace_premium_outlined:'medali',
  Icons.emoji_events:'piala', Icons.emoji_events_outlined:'piala',
  Icons.emoji_events_rounded:'piala',
  Icons.history:'logorhistory',
  Icons.lock:'lock', Icons.lock_outline:'lock', Icons.lock_rounded:'lock',
  Icons.lock_outline_rounded:'lock',
  Icons.info_outline:'info', Icons.help_outline:'question',
  Icons.check:'centang', Icons.check_circle:'centang',
  Icons.check_circle_outline:'centang', Icons.check_circle_rounded:'centang',
  Icons.close:'x', Icons.close_rounded:'x',
  Icons.hourglass_empty:'jampasir', Icons.hourglass_top_rounded:'jampasir',
  Icons.refresh:'refresh', Icons.storefront_rounded:'store',
  Icons.open_in_new_rounded:'bukatautan', Icons.download_rounded:'unduh',
  Icons.swap_horiz:'barter', Icons.swap_horiz_rounded:'barter',
  Icons.forum_rounded:'discuss', Icons.how_to_vote_rounded:'vote',
  Icons.visibility_rounded:'show', Icons.remove_red_eye_rounded:'show',
  Icons.record_voice_over_rounded:'announcement',
  Icons.auto_stories_outlined:'mydeck', Icons.style_outlined:'mydeck',
  Icons.water_drop:'bulirembun', Icons.water_drop_outlined:'bulirembun',
  Icons.eco:'helaidaun', Icons.eco_outlined:'helaidaun', Icons.eco_rounded:'helaidaun',
});

IconData iconFallback(String name) => switch(canonicalIconName(name)) {
  'back' || 'back2' => Icons.arrow_back,
  'suaranyala' => Icons.volume_up_rounded,
  'suaramati' => Icons.volume_off_rounded,
  'botollab' => Icons.science_rounded,
  'bulansabit' => Icons.nightlight_round,
  'matahari' || 'endday' => Icons.wb_sunny_outlined,
  'hatipenuh' => Icons.favorite_rounded,
  'hatikosong' => Icons.favorite_border_rounded,
  'lihatprofil' || 'identity' || 'character' || 'persona' => Icons.person_outline,
  'hapusdata' => Icons.delete_outline,
  'medali' => Icons.workspace_premium_outlined,
  'piala' || 'menang' || 'akhir-menang' => Icons.emoji_events_outlined,
  'logorhistory' || 'hari' => Icons.history,
  'lock' => Icons.lock_outline,
  'on' => Icons.toggle_on_outlined,
  'off' => Icons.toggle_off_outlined,
  'persen' => Icons.percent,
  'tautan' => Icons.link,
  'bukatautan' => Icons.open_in_new_rounded,
  'ubah' => Icons.edit_outlined,
  'unduh' => Icons.download_rounded,
  'baru' || 'plus' => Icons.add,
  'minus' || 'poinmin1' => Icons.remove,
  'poinplus1' => Icons.add_circle_outline,
  'simpan' => Icons.save_outlined,
  'takterbatas' => Icons.all_inclusive,
  'pesanataumail' || 'pesanatauemail' => Icons.mail_outline,
  'store' => Icons.storefront_rounded,
  'perbaikan' || 'settings' || 'customization' => Icons.settings_outlined,
  'discuss' || 'titlemusyawarah' => Icons.forum_rounded,
  'vote' => Icons.how_to_vote_rounded,
  'mydeck' || 'mydeck2' || 'salin' => Icons.style_outlined,
  'kirim' => Icons.send_outlined,
  'jampasir' || 'wait' || 'timer' => Icons.hourglass_empty,
  'alert' || 'danger' || 'tertuduh' => Icons.warning_amber_rounded,
  'keluar' || 'bubarkan' => Icons.logout,
  'centang' || 'dipilih' || 'dibeli' => Icons.check,
  'x' || 'silang' || 'kalah' || 'akhir-kalah' => Icons.close,
  'refresh' || 'barter' || 'change' => Icons.sync,
  'start' => Icons.play_arrow_rounded,
  'lewatisatu' || 'skip' => Icons.skip_next,
  'lewatiakhir' || 'skip2' => Icons.fast_forward,
  'show' => Icons.visibility_outlined,
  'hide' => Icons.visibility_off_outlined,
  'helaidaun' || 'donations' || 'showaddgraphic' => Icons.eco_outlined,
  'bulirembun' || 'bulirhitam' => Icons.water_drop_outlined,
  'addmember' => Icons.group_add_outlined,
  'home' || 'roomcreate' || 'joinroom' || 'jointoroom' => Icons.home_outlined,
  'roomcode' => Icons.password,
  'host' => Icons.manage_accounts_outlined,
  'menu' => Icons.menu,
  'notification' => Icons.notifications_outlined,
  'touch' => Icons.touch_app_outlined,
  'samadengan' => Icons.drag_handle,
  'titlepasarriset' => Icons.science_rounded,
  'titlepersembahan' => Icons.eco_outlined,
  'item' => Icons.auto_awesome,
  _ => Icons.info_outline,
};

// Tombol memakai ikon yang lebih besar daripada indikator status sebaris.
const double embunActionIconSize = 32;
const double embunNavigationIconSize = 40;

double embunButtonIconSize(String? name, double requested, bool inButton) {
  if (!inButton) {
    return requested;
  }
  final canonical = name == null ? null : canonicalIconName(name);
  final minimum = canonical == 'back' || canonical == 'back2' || canonical == 'x'
      ? embunNavigationIconSize : embunActionIconSize;
  return requested < minimum ? minimum : requested;
}

/// Pengganti Icon yang mempertahankan ukuran dan semantik, memakai ilustrasi
/// hanya jika ada padanan yang benar. Simbol fungsi yang belum tersedia tetap
/// terlihat; gambar hilang tidak membuat tombol kosong.
class EmbunIcon extends StatelessWidget {
  const EmbunIcon(this.icon, {super.key,this.size,this.color,this.semanticLabel,
    this.textDirection,this.shadows,this.asset});
  final IconData? icon;
  final String? asset;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final List<Shadow>? shadows;
  @override
  Widget build(BuildContext context) {
    final name=asset ?? embunMaterialIcons[icon];
    if (name == null) {
      final inButton = context.findAncestorWidgetOfExactType<IconButton>() != null;
      final dimension = embunButtonIconSize(null,
          size ?? IconTheme.of(context).size ?? 24.0, inButton);
      return Icon(icon, size: dimension, color: color,
        semanticLabel: semanticLabel, textDirection: textDirection, shadows: shadows);
    }
    return EmbunAssetIcon(name, size:size, color:color, semanticLabel:semanticLabel,
      fallback:icon);
  }
}

class EmbunAssetIcon extends StatelessWidget {
  const EmbunAssetIcon(this.name,{super.key,this.size,this.width,this.height,
    this.color,this.semanticLabel,this.fallback});
  final String name;
  final double? size,width,height;
  final Color? color;
  final String? semanticLabel;
  final IconData? fallback;
  @override
  Widget build(BuildContext context) {
    final theme=IconTheme.of(context);
    final inButton = context.findAncestorWidgetOfExactType<IconButton>() != null;
    final dimension = embunButtonIconSize(name,
        size ?? theme.size ?? 24.0,
        inButton && width == null && height == null);
    final w=width ?? dimension, h=height ?? dimension;
    final path=ikonPath(name);
    final glyph=Icon(fallback ?? iconFallback(name),size:dimension,color:color,
      semanticLabel:null);
    final sourceColor=color ?? theme.color;
    final alpha=(sourceColor?.a ?? 1.0)*(theme.opacity ?? 1.0);
    final asset=path==null ? Center(child:glyph) : Opacity(
      opacity:alpha.clamp(0.0,1.0).toDouble(),
      child:Image.asset(path,fit:BoxFit.contain,cacheWidth:(w*3).round(),
        excludeFromSemantics:true,errorBuilder:(_,_,_)=>Center(child:glyph)),
    );
    return Semantics(label:semanticLabel,image:semanticLabel!=null,
      child:SizedBox(width:w,height:h,child:asset));
  }
}

/// Saklar gambar dengan fokus keyboard dan semantik checked yang tetap utuh.
class EmbunToggle extends StatelessWidget {
  const EmbunToggle({super.key,required this.value,required this.onChanged,
    this.semanticLabel});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label:semanticLabel, toggled:value, enabled:onChanged!=null,
    child:IconButton(
      tooltip:semanticLabel,
      onPressed:onChanged==null ? null : () => onChanged!(!value),
      icon:EmbunAssetIcon(value?'on':'off',width:52,height:36,
        color:onChanged==null ? Colors.white38 : null),
    ),
  );
}
