import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:flutter/material.dart';

import 'summary.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = ArticleViewModel(ArticleModel());

    return MaterialApp(
      home: ArticleView(),
    );
  }
}

// The Article Model - handles data in the MVVM architecture 
class ArticleModel {
  Future<Summary> getRandomArticleSummary() async {
    // Create url to fetch resource from
    final uri = Uri.https(
      'en.wikipedia.org',
      '/api/rest_v1/page/random/summary',
    );

    // send the request to the url and await a response
    final response = await get(uri);

    // Handle unsuccessful responses  
    if (response.statusCode != 200) {
      throw const HttpException('Failed to update resource');
    }

    // Parse the JSON response into a summary class object
    return Summary.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }
}

// ChangeNotifier is a class that notifies listeners when it's data changes, allowing UI to update
class ArticleViewModel extends ChangeNotifier {
  final ArticleModel model;
  Summary? summary; // The current Wikipedia article data
  Exception? error; // Any error that occurred during fetching
  bool isLoading = false; // A flag to show progress indicators

  ArticleViewModel(this.model) {
    fetchArticle();
  }

  // Method used to fetch an article 
  Future<void> fetchArticle() async {
    isLoading = true;
    notifyListeners();

    try {
      summary = await model.getRandomArticleSummary();
      print("Article Loaded: ${summary!.titles.normalized}");
      error = null;
    } on HttpException catch (e) {
      print("Error loading article: ${e.message}");
      error = e;
      summary = null;
    }

    isLoading = false;
    notifyListeners();
  }

}

class ArticleView extends StatefulWidget {
  const ArticleView({super.key});

  @override
  State<StatefulWidget> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  final ArticleViewModel viewModel = ArticleViewModel(ArticleModel());

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    viewModel.fetchArticle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wikipedia Flutter"),),
      body: ListenableBuilder( // ListenableBuilder listens for state changes and passes it to the ChangeNotifier ogject.
        listenable: viewModel, 
        builder: (context, _) {
          return switch ((
            viewModel.isLoading,
            viewModel.summary,
            viewModel.error,
          )) {
              (true, _, _) => const CircularProgressIndicator(),
              (_, _, final Exception e) => Text('Error: $e'),
              (_, final summary?, _) => ArticlePage(
                summary: summary,
                nextArticleCallback: viewModel.fetchArticle,
              ),
              _ => const Text('Something went wrong!'),
          };
        },
      ),
    );
  }
}

// ArticlePage is a widget that displays the actual article content. This reusable widget takes summary data and a callback function:
class ArticlePage extends StatelessWidget {
  const ArticlePage({
    super.key,
    required this.summary,
    required this.nextArticleCallback,
  });

  final Summary summary;
  final VoidCallback nextArticleCallback;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ArticleWidget(summary: summary),
          ElevatedButton(
            onPressed: nextArticleCallback,
            child: const Text('Next Article'),
          )
        ],
      ),
    );
  }
}

class ArticleWidget extends StatelessWidget {
  const ArticleWidget({
    super.key,
    required this.summary,
  });

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        spacing: 10,
        children: [
          if (summary.hasImage) Image.network(summary.originalImage!.source),
          Text(
            summary.titles.normalized,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          if (summary.description != null)
            Text(
              summary.description!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(summary.extract),
        ],
      ),
    );
  }
}