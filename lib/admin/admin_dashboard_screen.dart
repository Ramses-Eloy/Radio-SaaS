import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../dashboard_web/screens/dashboard_screen.dart';
import '../dashboard_web/screens/login_screen.dart';
import '../dashboard_web/services/client_data_store.dart';
import '../dashboard_web/services/emisora_repository.dart';
import '../dashboard_web/superadmin/screens/superadmin_dashboard_screen.dart';
import '../dashboard_web/superadmin/services/superadmin_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final EmisoraRepository _emisoraRepository;
  late final ClientDataStore _clientDataStore;

  @override
  void initState() {
    super.initState();
    _emisoraRepository = EmisoraRepository();
    _clientDataStore = ClientDataStore(_emisoraRepository);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.podcasts, size: 48),
                  SizedBox(height: 20),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Iniciando panel…'),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Detección de rol SuperAdmin
        if (SuperAdminRepository.isSuperAdmin(user.email)) {
          return const SuperAdminDashboardScreen();
        }

        // Panel de cliente regular
        return DashboardScreen(
          repository: _emisoraRepository,
          dataStore: _clientDataStore,
        );
      },
    );
  }
}

