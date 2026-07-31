part of '../../main.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override State<SessionsPage> createState() => _SessionsPageState();
}
class _SessionsPageState extends State<SessionsPage> {
  List<SessionModel> sessions = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final v = await WorkerApiService().fetchSessions(); if (mounted) setState(() => sessions = v); } on ApiException catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); } finally { if(mounted) setState(() => loading=false); } }
  Future<void> _remove(SessionModel session) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(session.current ? 'Sign out this device?' : 'Sign out device?'), content: Text(session.current ? 'You will return to the login screen.' : '${session.device} will lose access to your account.'), actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Sign out'))]));
    if(yes!=true)return;
    try { await WorkerApiService().removeSession(session.id); if (!mounted) return; if(session.current){ await ApiClient.instance.setToken(null); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder:(_)=>const OnboardingPage()), (_)=>false); } else { await _load(); } } on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Login & security')),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(children:sessions.map((s)=>MenuRow(LucideIcons.smartphone,s.device,s.current?'This device • ${s.lastUsedAgo}':'Last used ${s.lastUsedAgo}',()=>_remove(s),trailing:s.current?const StatusPill('Current',Color(0xFFECFDF5),Color(0xFF047857)):null)).toList())));
}
