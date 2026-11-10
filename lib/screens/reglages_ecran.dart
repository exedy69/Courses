import 'package:flutter/material.dart';

import '../db/base_donnees.dart';
import '../services/reglages.dart';
import '../services/service_notifications.dart';
import '../services/sync_service.dart';
import 'fiabilite_xiaomi.dart';
import 'partage_config.dart';

class EcranReglages extends StatefulWidget {
  const EcranReglages({super.key});

  @override
  State<EcranReglages> createState() => _EcranReglagesState();
}

class _EcranReglagesState extends State<EcranReglages> {
  final _r = Reglages.instance;
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _prenom = TextEditingController();
  Bilan _bilan = const Bilan(0, 0);
  String _testSync = '';

  static const _jours = ['Aucun', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  @override
  void initState() {
    super.initState();
    _url.text = _r.syncUrl;
    _token.text = _r.syncToken;
    _prenom.text = _r.prenom;
    BaseDonnees.version.addListener(_chargerBilan);
    SyncService.instance.etat.addListener(_maj);
    _chargerBilan();
  }

  @override
  void dispose() {
    BaseDonnees.version.removeListener(_chargerBilan);
    SyncService.instance.etat.removeListener(_maj);
    _url.dispose();
    _token.dispose();
    _prenom.dispose();
    super.dispose();
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  Future<void> _chargerBilan() async {
    final b = await BaseDonnees.instance.bilan();
    if (mounted) setState(() => _bilan = b);
  }

  Future<void> _basculerNotifs(bool v) async {
    final n = ServiceNotifications.instance;
    if (v) {
      final ok = await n.demanderPermission();
      if (!ok) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Notifications désactivées'),
            content: const Text(
                'Android a refusé l\'autorisation. Ouvre les informations de l\'appli > Notifications, active-les, puis reviens ici.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
        return;
      }
      await _r.setNotifsActives(true);
      await n.reprogrammer();
    } else {
      await _r.setNotifsActives(false);
      await n.annulerTout();
    }
    setState(() {});
  }

  Future<void> _choisirHeure() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _r.heure, minute: _r.minute),
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
    );
    if (t == null) return;
    await _r.setHeure(t.hour, t.minute);
    await ServiceNotifications.instance.reprogrammer();
    setState(() {});
  }

  /// Récupère l'URL et le jeton depuis le QR code affiché par un autre téléphone.
  Future<void> _importerConfig() async {
    final config = await Navigator.push<ConfigSync>(
        context, MaterialPageRoute(builder: (_) => const EcranScanConfig()));
    if (config == null) return;
    await _r.setSyncUrl(config.url);
    await _r.setSyncToken(config.token);
    await _r.setSyncActif(true);
    _url.text = config.url;
    _token.text = config.token;
    if (!mounted) return;
    setState(() => _testSync = 'Configuration importée');
    SyncService.instance.synchroniser(complet: true);
  }

  String _dateLisible(String? iso) {
    if (iso == null || iso.length < 16) return 'jamais';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return 'jamais';
    String z(int n) => n.toString().padLeft(2, '0');
    return '${z(d.day)}/${z(d.month)}/${d.year} ${z(d.hour)}:${z(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_bilan.pourcentageSauves * 100).round();
    final sync = SyncService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Bilan des 30 derniers jours', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_bilan.total == 0)
              const Text('Glisse tes produits vers la droite (consommé) ou la gauche (jeté) dans « Mon stock » pour voir ton bilan ici.')
            else ...[
              Text('${_bilan.consommes} consommé(s) · ${_bilan.jetes} jeté(s) · $pct % sauvés'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _bilan.pourcentageSauves, minHeight: 10),
            ],
            const Divider(height: 32),
            TextField(
              controller: _prenom,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ton prénom (facultatif)',
                helperText: 'Affiché à côté des produits que tu ajoutes',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _r.setPrenom(v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Rappels de péremption et de courses'),
              value: _r.notifsActives,
              onChanged: _basculerNotifs,
            ),
            ListTile(
              title: const Text('Heure du rappel quotidien'),
              trailing: Text(
                  '${_r.heure.toString().padLeft(2, '0')}:${_r.minute.toString().padLeft(2, '0')}'),
              onTap: _choisirHeure,
            ),
            ListTile(
              title: const Text('Jour de courses'),
              subtitle: const Text('Rappel hebdomadaire à 19:30'),
              trailing: DropdownButton<int>(
                value: _r.jourCourses,
                items: [
                  for (var i = 0; i < _jours.length; i++)
                    DropdownMenuItem(value: i, child: Text(_jours[i])),
                ],
                onChanged: (v) async {
                  await _r.setJourCourses(v ?? 0);
                  await ServiceNotifications.instance.reprogrammer();
                  setState(() {});
                },
              ),
            ),
            ListTile(
              title: const Text('Relance anti-oubli'),
              subtitle: const Text('Si aucun produit n\'a été ajouté depuis…'),
              trailing: DropdownButton<int>(
                value: const [5, 7, 10, 14, 21].contains(_r.seuilSilence) ? _r.seuilSilence : 10,
                items: [
                  for (final j in const [5, 7, 10, 14, 21])
                    DropdownMenuItem(value: j, child: Text('$j jours')),
                ],
                onChanged: (v) async {
                  await _r.setSeuilSilence(v ?? 10);
                  setState(() {});
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('Fiabilité des rappels (Xiaomi)'),
              subtitle: const Text('Pour que les rappels arrivent vraiment'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EcranFiabiliteXiaomi())),
            ),
            const Divider(height: 32),
            Text('Synchronisation Google Sheets (facultatif)',
                style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Synchroniser'),
              value: _r.syncActif,
              onChanged: (v) async {
                await _r.setSyncActif(v);
                setState(() {});
                if (v) sync.synchroniser(complet: true);
              },
            ),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'URL de l\'application web', border: OutlineInputBorder()),
              onChanged: (v) async {
                await _r.setSyncUrl(v);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Jeton', border: OutlineInputBorder()),
              onChanged: (v) async {
                await _r.setSyncToken(v);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() => _testSync = 'Test en cours…');
                      final res = await sync.tester();
                      if (mounted) setState(() => _testSync = res);
                    },
                    child: const Text('Tester la connexion'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => sync.synchroniser(force: true, complet: true),
                    child: const Text('Synchroniser maintenant'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _r.syncUrl.isEmpty || _r.syncToken.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EcranPartageConfig(
                                    url: _r.syncUrl, token: _r.syncToken))),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Partager (QR)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importerConfig,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner un QR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_testSync.isNotEmpty) Text(_testSync),
            Text('Dernière synchro réussie : ${_dateLisible(_r.syncDernierOk)}'),
            if (sync.etat.value.isNotEmpty) Text('État : ${sync.etat.value}'),
            const SizedBox(height: 24),
            Text(
              'Les données restent sur ce téléphone ; la synchro Google Sheets est facultative.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
