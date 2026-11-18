import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/queue_provider.dart';
import '../providers/auth_provider.dart';
import '../models/client.dart';
import '../models/queue_state.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final queueProvider = context.watch<QueueProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAdmin) {
      return const Center(
        child: Text('Access denied'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: queueProvider.refreshQueue,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: queueProvider.state == QueueState.loading
          ? const Center(child: CircularProgressIndicator())
          : queueProvider.clients.isEmpty
              ? const Center(child: Text('No clients in queue'))
              : ListView.builder(
                  itemCount: queueProvider.clients.length,
                  itemBuilder: (context, index) {
                    final client = queueProvider.clients[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text((index + 1).toString()),
                        ),
                        title: Text(client.name),
                        subtitle: Text(client.hasLocation
                            ? client.locationText
                            : 'No location'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeClient(context, client.id),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: authProvider.isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddClientDialog(context),
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  void _removeClient(BuildContext context, String id) {
    context.read<QueueProvider>().removeClient(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client removed')),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Client'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Client Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text;
              Navigator.pop(context);
              if (name.isNotEmpty) {
                context.read<QueueProvider>().addClient(name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}