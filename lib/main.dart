// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'German Articles',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ArticleLearningScreen(),
    );
  }
}

class Word {
  final String noun;
  final String article;
  int rank;

  Word({
    required this.noun,
    required this.article,
    this.rank = 0,
  });

  Map<String, dynamic> toJson() => {
        'noun': noun,
        'article': article,
        'rank': rank,
      };

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        noun: json['noun'],
        article: json['article'],
        rank: json['rank'],
      );
}

class ArticleLearningScreen extends StatefulWidget {
  const ArticleLearningScreen({super.key});

  @override
  State<ArticleLearningScreen> createState() => _ArticleLearningScreenState();
}

class _ArticleLearningScreenState extends State<ArticleLearningScreen> {
  List<Word> words = [];
  Word? currentWord;
  String? selectedArticle;
  bool showResult = false;
  final articles = ['der', 'die', 'das'];

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  Future<void> loadWords() async {
    // Try to load saved state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedWords = prefs.getString('words');

    if (savedWords != null) {
      final List<dynamic> decoded = json.decode(savedWords);
      words = decoded.map((w) => Word.fromJson(w)).toList();
    } else {
      // Load initial data from assets
      final String data = await rootBundle.loadString('assets/nouns.txt');
      final List<String> lines = data.split('\n');
      words = lines.where((line) => line.trim().isNotEmpty).map((line) {
        final parts = line.split('\t');
        return Word(
            noun: parts[0].trim(), article: parts[1].trim().toLowerCase());
      }).toList();
    }

    selectNextWord();
  }

  void selectNextWord() {
    if (words.isEmpty) return;

    // Sort words by rank and select the first one
    words.shuffle();
    words.sort((a, b) => a.rank.compareTo(b.rank));

    setState(() {
      currentWord = words[0];
      showResult = false;
      selectedArticle = null;
    });
  }

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(words.map((w) => w.toJson()).toList());
    await prefs.setString('words', encoded);
  }

  void handleArticleSelection(String article) {
    if (showResult || currentWord == null) return;

    final isCorrect =
        article.toLowerCase() == currentWord!.article.toLowerCase();

    setState(() {
      selectedArticle = article;
      showResult = true;

      // Update word rank
      final wordIndex = words.indexWhere((w) => w.noun == currentWord!.noun);
      if (wordIndex != -1) {
        words[wordIndex].rank += isCorrect ? 1 : -1;
      }
    });

    saveProgress();

    // Move to next word after delay
    Future.delayed(const Duration(seconds: 2), () {
      selectNextWord();
    });
  }

  Color getButtonColor(String article) {
    if (!showResult || selectedArticle == null) {
      return Colors.blue;
    }

    if (article == currentWord!.article) {
      return Colors.green;
    }

    if (article == selectedArticle) {
      return Colors.red;
    }

    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        showResult
                            ? '${currentWord!.article} ${currentWord!.noun}'
                            : currentWord?.noun ?? 'Loading...',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  children: articles.map((article) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: showResult
                              ? () {} // Empty function instead of null
                              : () => handleArticleSelection(article),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: getButtonColor(article),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            // Disable the button's splash effect when showing result
                            enableFeedback: !showResult,
                            splashFactory: showResult ? NoSplash.splashFactory : null,
                          ),
                          child: Text(
                            article,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Text('Version 0.1 • Current word rank: ${currentWord?.rank ?? 0}'),
            ],
          ),
        ),
      ),
    );
  }
}
