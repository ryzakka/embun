import 'package:flutter/material.dart';
import '../../data/asset_catalog.dart';
import '../../data/icon_catalog.dart';
import '../common/art.dart';
import '../common/ornate.dart';

/// Pemeriksaan aset setempat; tidak membaca atau menulis Supabase.
class IconPreviewPage extends StatefulWidget {
  const IconPreviewPage({super.key});
  @override State<IconPreviewPage> createState() => _IconPreviewPageState();
}
class _IconPreviewPageState extends State<IconPreviewPage> {
  bool _loading = true;
  String _query='';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    await AssetCatalog.load();
    if (mounted) setState(() => _loading=false);
  }
  @override Widget build(BuildContext context) {
    final names=embunIconNames.where((n)=>n.contains(_query)).toList()..sort();
    final missing=embunIconNames.where((n)=>AssetCatalog.I.file(ikonDir,n)==null).length;
    return Scaffold(
      appBar:AppBar(
        leading:IconButton(tooltip:'Kembali',icon:const GameIcon('back2',size:26),
          onPressed:()=>Navigator.of(context).pop()),
        title:const Text('Pratinjau ikon UI'),
      ),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.all(12), child:Column(children:[
          Text(_loading?'Memuat ikon…':'${embunIconNames.length} nama ikon · $missing gambar utama belum tersedia',
            style:const TextStyle(color:EmbunColors.gold)),
          const SizedBox(height:8),
          TextField(onChanged:(v)=>setState(()=>_query=v.trim().toLowerCase()),
            decoration:const InputDecoration(labelText:'Cari nama ikon')),
        ])),
        Expanded(child:GridView.builder(
          padding:const EdgeInsets.all(12),
          gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent:180,mainAxisExtent:142,crossAxisSpacing:8,mainAxisSpacing:8),
          itemCount:names.length,
          itemBuilder:(_,i){
            final name=names[i];final primary=AssetCatalog.I.file(ikonDir,name);
            final path=ikonPath(name);
            return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
              GameIcon(name,size:54),const SizedBox(height:6),
              Text(name,maxLines:1,overflow:TextOverflow.ellipsis),
              const SizedBox(height:3),
              Flexible(child:Text(primary!=null?'Gambar utama':path!=null?'Gambar kompatibilitas':'Simbol pengganti',
                textAlign:TextAlign.center,style:TextStyle(fontSize:11,
                  color:primary!=null?EmbunColors.leaf:EmbunColors.gold))),
            ])));
          },
        )),
      ])),
    );
  }
}
