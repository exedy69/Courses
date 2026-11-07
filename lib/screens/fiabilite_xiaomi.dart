import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../services/service_notifications.dart';

class EcranFiabiliteXiaomi extends StatelessWidget {
  const EcranFiabiliteXiaomi({super.key});

  static const _etapes = <(String, String)>[
    ('Démarrage automatique',
        'Autorise l\'appli à démarrer automatiquement (menu « Autostart » ou « Démarrage automatique » dans les informations de l\'appli ou la sécurité).'),
    ('Économiseur de batterie',
        'Règle l\'économiseur de batterie de l\'appli sur « Aucune restriction » pour que HyperOS ne la mette pas en veille profonde.'),
    ('Verrouiller dans les applications récentes',
        'Ouvre la vue des applications récentes, appuie longuement sur la carte de Frigo Malin et choisis l\'option de verrouillage (cadenas).'),
    ('Notifications',
        'Autorise les notifications, y compris sur l\'écran de verrouillage et en bannière, pour la catégorie « Rappel quotidien ».'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiabilité des rappels (Xiaomi)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'HyperOS arrête volontiers les applis en arrière-plan, ce qui peut retarder ou supprimer les rappels. '
              'Vérifie ces quatre points une fois ; les intitulés exacts varient selon la version du système.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _etapes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(_etapes[i].$1),
                  subtitle: Text(_etapes[i].$2),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => AppSettings.openAppSettings(),
                icon: const Icon(Icons.settings_applications_outlined),
                label: const Text('Ouvrir les informations de l\'appli'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await ServiceNotifications.instance.demanderPermission();
                  if (!ok) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Notifications refusées : autorise-les d\'abord dans les réglages.')));
                    return;
                  }
                  await ServiceNotifications.instance.programmerTest();
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Notification de test programmée dans 1 minute. Ferme l\'appli et patiente.')));
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Envoyer une notification de test dans 1 minute'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
