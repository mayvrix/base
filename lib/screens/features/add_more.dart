import 'dart:io'; 
import 'dart:typed_data';

import 'package:base/services/upload_song.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Your project imports
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';

class AddMusicScreen extends StatefulWidget {
  const AddMusicScreen({super.key});

  @override
  State<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends State<AddMusicScreen> {
  final _formKey = GlobalKey<FormState>();

  File? selectedFile;
  Uint8List? coverArt;
  File? coverFile;

  String name = "";
  String artist = "";
  String album = "";
  String lyrics = "";
  String year = DateTime.now().year.toString();
  String type = "song";

  final List<String> years =
      List.generate(100, (index) => (DateTime.now().year - index).toString());

  final List<String> types = [
    "song",
    "instrumental",
    "songENG",
    "songHND",
    "extra"
  ];

  /// Pick audio file
  Future<void> _pickAudio() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) return;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'flac', 'wav'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  /// Pick image
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        coverFile = File(result.files.single.path!);
        coverArt = coverFile!.readAsBytesSync();
      });
    }
  }

  bool get isFormComplete {
    return name.isNotEmpty &&
        artist.isNotEmpty &&
        album.isNotEmpty &&
        lyrics.isNotEmpty &&
        selectedFile != null &&
        coverArt != null;
  }

  Future<void> _uploadMusic() async {
    if (!isFormComplete) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading music...")),
    );

    try {
      await UploadService.uploadSong(
        name: name,
        artist: artist,
        album: album,
        lyrics: lyrics,
        year: year,
        type: type,
        audioFile: selectedFile!,
        coverFile: coverFile!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ $name uploaded successfully!")),
      );
      Navigator.pop(context);
    } catch (e, stackTrace) {
      final errorMsg =
          "❌ Upload failed:\nError Type: ${e.runtimeType}\nError: $e\nStackTrace:\n$stackTrace";

      debugPrint(errorMsg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Text(
              errorMsg,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final s = S.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add Music",
          style: TextStyle(
            fontFamily: "monospace",
            letterSpacing: -0.5,
            wordSpacing: -3.5,
            color: colors.text,
            fontSize: s.sp(0.05),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s.pad(0.04)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image + Audio
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: s.hp(0.18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(s.rad(0.06)),
                          color: colors.newOnPrimary.withOpacity(0.1),
                        ),
                        child: coverArt != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.06)),
                                child:
                                    Image.memory(coverArt!, fit: BoxFit.cover),
                              )
                            : Center(
                                child: Icon(Icons.image,
                                    color: colors.text, size: s.sp(0.08))),
                      ),
                    ),
                  ),
                  SizedBox(width: s.wp(0.04)),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickAudio,
                      child: Container(
                        height: s.hp(0.18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(s.rad(0.3)),
                          color: colors.newPrimary,
                        ),
                        child: Center(
                          child: Icon(Icons.music_note,
                              color: selectedFile != null
                                  ? Colors.white
                                  : colors.newOnPrimary,
                              size: s.sp(0.08)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: s.hp(0.03)),
              _buildTextField("Name", (val) => name = val),
              SizedBox(height: s.hp(0.015)),
              _buildTextField("Artist", (val) => artist = val),
              SizedBox(height: s.hp(0.015)),
              _buildTextField("Album", (val) => album = val),
              SizedBox(height: s.hp(0.015)),
              _buildTextField("Lyrics", (val) => lyrics = val, maxLines: 4),
              SizedBox(height: s.hp(0.015)),

              // Year + Type
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: year,
                      decoration: InputDecoration(
                        labelText: "Year",
                        labelStyle: TextStyle(color: colors.newPrimary),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(s.rad(0.06)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(s.rad(0.06)),
                          borderSide: BorderSide(
                              color: colors.newOnPrimary, width: 2),
                        ),
                      ),
                      items: years
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (val) => setState(() => year = val!),
                    ),
                  ),
                  SizedBox(width: s.wp(0.04)),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: "Type",
                        labelStyle:
                            TextStyle(color: colors.newPrimary),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(s.rad(0.06)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(s.rad(0.06)),
                          borderSide: BorderSide(
                              color: colors.newOnPrimary, width: 2),
                        ),
                      ),
                      items: types
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => type = val!),
                    ),
                  ),
                ],
              ),

              SizedBox(height: s.hp(0.03)),

              // Submit button
              GestureDetector(
                onTap: isFormComplete ? _uploadMusic : null,
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(vertical: s.hp(0.01)),
                  decoration: BoxDecoration(
                    color: isFormComplete
                        ? colors.newPrimary
                        : colors.newPrimary.withOpacity(0.3),
                    borderRadius:
                        BorderRadius.circular(s.rad(0.09)),
                  ),
                  child: Icon(
                    Icons.arrow_right_alt,
                    color: isFormComplete
                        ? colors.text
                        : colors.newOnPrimary,
                    size: s.sp(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    Function(String) onChanged, {
    int maxLines = 1,
  }) {
    final colors = context.appColors;
    final s = S.of(context);

    return TextFormField(
      maxLines: maxLines,
      onChanged: (val) => setState(() => onChanged(val)),
      style: TextStyle(
        color: colors.text,
        fontFamily: "monospace",
        letterSpacing: -0.5,
        wordSpacing: -3.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: colors.text.withOpacity(0.5),
          fontFamily: "monospace",
          letterSpacing: -0.5,
          wordSpacing: -3.5,
        ),
        filled: true,
        fillColor: colors.newOnPrimary.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.rad(0.06)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
