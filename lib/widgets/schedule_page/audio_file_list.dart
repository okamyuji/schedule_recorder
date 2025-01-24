import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:schedule_recorder/models/audio_file.dart';

class AudioFileList extends StatelessWidget {
  final List<AudioFile> files;
  final void Function(AudioFile) onPlayTap;
  final void Function(AudioFile) onDeleteTap;

  const AudioFileList({
    super.key,
    required this.files,
    required this.onPlayTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          leading: Icon(
            file.isShared ? Icons.share : Icons.mic,
            color: Theme.of(context).primaryColor,
          ),
          title: Text(file.name),
          subtitle: Text(
            DateFormat('yyyy/MM/dd HH:mm').format(file.createdAt),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => onPlayTap(file),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDeleteTap(file),
              ),
            ],
          ),
        );
      },
    );
  }
}
