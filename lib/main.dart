import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:darq/darq.dart';
import 'dart:math';
import 'base_learning.dart';

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

class Word extends LearnableItem {
  final String noun;
  final String article;

  Word({
    super.rank = 0,
    required this.noun,
    required this.article,
  });

  @override
  Map<String, dynamic> toJson() => {
    'rank': rank,
    'noun': noun,
    'article': article,
  };

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    rank: json['rank'],
    noun: json['noun'],
    article: json['article'],
  );

  @override
  bool isNotEmpty() => noun.isNotEmpty && article.isNotEmpty;
}

class SavedState implements BaseSavedState {
  final List<Word> words;

  SavedState({
    required this.words,
  });

  @override
  Map<String, dynamic> toJson() => {'words': words.map((w) => w.toJson()).toList(),};

  factory SavedState.fromJson(Map<String, dynamic> json) => SavedState(
    words: (json['words'] as List).map((w) => Word.fromJson(w)).where((word) => word.isNotEmpty()).toList(),
  );
}

class ArticleLearningScreen extends BaseLearningScreen<Word> {
  const ArticleLearningScreen({super.key});

  @override
  State<ArticleLearningScreen> createState() => _ArticleLearningScreenState();
}

class _ArticleLearningScreenState extends BaseLearningScreenState<Word, ArticleLearningScreen> {
  final articles = ['der', 'die', 'das'];
  String? selectedArticle;
  bool showResult = false;

  @override
  String get version => '0.8.0';

  @override
  String get prefsKey => 'words';

  @override
  void loadSavedState(String savedStateJson) {
    final savedState = SavedState.fromJson(json.decode(savedStateJson));
    items = savedState.words;
  }

  @override
  Future<void> loadInitState() async {
    final String data = await rootBundle.loadString('assets/nouns.txt');
    final List<String> lines = data.split('\n');
    items = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
      final parts = line.split('\t');
      return Word(noun: parts[0].trim(), article: parts[1].trim().toLowerCase());
    }).where((word) => word.isNotEmpty()).toList();
    items.shuffle();
  }

  @override
  SavedState getSavedState() {
    return SavedState(words: items);
  }

  void handleArticleSelection(String article) {
    if (showResult || currentItem == null) return;
    final isCorrect = article == currentItem!.article;

    setState(() {
      showResult = true;
      selectedArticle = article;

      if (isCorrect) {
        if (currentItem!.rank == 0) {
          currentItem!.rank = 6;
        } else {
          currentItem!.rank += 1;
        }
      } else {
        currentItem!.rank = 1;
      }

      items.removeAt(0);
      var index = pow(2, (currentItem!.rank + 1)).toInt();
      if (index < items.length) {
        items.insert(index, currentItem!);
      } else {
        items.add(currentItem!);
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        showResult = false;
        selectedArticle = null;
      });
      selectNextItem();
    });
  }

  Color getButtonColor(String article) {
    if (!showResult || selectedArticle == null) {
      return Colors.blue;
    }

    if (article == currentItem!.article) {
      return Colors.green;
    }

    if (article == selectedArticle) {
      return Colors.red;
    }

    return Colors.blue;
  }

  @override
  Widget buildHeader() {
    var used = items.where((x) => x.rank > 0).toList();
    var learned = used.where((x) => x.rank > 8).toList();
    var points = used.sum((word) => word.rank);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(children: [
          const Icon(Icons.list, size: 30, color: Colors.black45),
          Text(' ${items.length}', style: Theme.of(context).textTheme.bodyLarge),
        ]),
        Row(children: [
          const Icon(LucideIcons.check, size: 30, color: Colors.green),
          Text(' ${used.length}', style: Theme.of(context).textTheme.bodyLarge),
        ]),
        Row(children: [
          const Icon(LucideIcons.checkCheck, size: 30, color: Colors.teal),
          Text(' ${learned.length}', style: Theme.of(context).textTheme.bodyLarge),
        ]),
        Row(children: [
          const Icon(Icons.emoji_events, size: 25, color: Colors.amber),
          Text(' $points', style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ],
    );
  }

  @override
  Widget buildWordCard() {
    return Center(
      child: Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showResult)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Icon(
                      currentItem!.rank == 1 ? Icons.close : Icons.check,
                      color: currentItem!.rank == 1 ? Colors.red : Colors.green,
                      size: 30,
                    ),
                  ),
                Text(
                  showResult
                      ? '${currentItem!.article} ${currentItem!.noun}'
                      : currentItem?.noun ?? 'Loading...',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        children: articles.map((article) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                onPressed: showResult ? null : () => handleArticleSelection(article),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getButtonColor(article),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: getButtonColor(article),
                  disabledForegroundColor: Colors.white,
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
    );
  }
}