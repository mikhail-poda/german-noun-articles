import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
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
    // Load initial data from assets
    final String data = await rootBundle.loadString('assets/nouns.txt');
    final List<String> lines = data.split('\n');
    final List<Word> assetWords = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split('\t');
      return Word(noun: parts[0].trim(), article: parts[1].trim().toLowerCase());
    }).toList();

    // Try to load saved state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedWords = prefs.getString('words');

    // If no saved words exist, use all words from assets
    if (savedWords == null) {
      words = assetWords;
      words.shuffle();
    } else {
      final List<dynamic> decoded = json.decode(savedWords);
      final List<Word> existingWords =
          decoded.map((w) => Word.fromJson(w)).toList();

      // Create a map of existing words for quick lookup
      final Map<String, Word> existingWordsMap = {
        for (var word in existingWords) word.noun: word
      };

      // Add new words from assets that don't exist in saved words
      for (var assetWord in assetWords) {
        if (!existingWordsMap.containsKey(assetWord.noun)) {
          existingWords.add(assetWord);
        }
      }

      words = existingWords;
    }

    selectNextWord();
  }

  void selectNextWord() {
    if (words.isEmpty) return;

    setState(() {
      showResult = false;
      currentWord = words[0];
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
    final isCorrect = article == currentWord!.article;

    setState(() {
      showResult = true;
      selectedArticle = article;

      if (isCorrect) {
        if (currentWord!.rank == 0) {
          currentWord!.rank = 6;
        } else {
          currentWord!.rank += 1;
        }
      } else {
        currentWord!.rank = 1;
      }

      words.removeAt(0);
      var index = 3 * pow(2, (currentWord!.rank - 1)).toInt();
      if (index < words.length) {
        words.insert(index, currentWord!);
      } else {
        words.add(currentWord!);
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
              Text('${words.length} • ${words.where((x) => x.rank > 0).length} • ${words.where((x) => x.rank > 8).length}',
                  style: Theme.of(context).textTheme.bodyLarge),
              Expanded(
                child: Center(
                  child: Card(
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      child: IntrinsicWidth(
                        // This makes the card wrap around content
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          // This keeps the Row compact
                          children: [
                            if (showResult)
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Icon(
                                  currentWord!.rank == 1
                                      ? Icons.close
                                      : Icons.check,
                                  color: currentWord!.rank == 1
                                      ? Colors.red
                                      : Colors.green,
                                  size: 30,
                                ),
                              ),
                            Text(
                              showResult
                                  ? '${currentWord!.article} ${currentWord!.noun}'
                                  : currentWord?.noun ?? 'Loading...',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
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
                              ? () {}
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
              Text('Version 0.5 • Current word rank: ${currentWord?.rank ?? 0}'),
            ],
          ),
        ),
      ),
    );
  }
}
