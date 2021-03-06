library flappy_search_bar;

import 'dart:async';

import 'package:async/async.dart';
import 'package:flappy_search_bar/scaled_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
//import 'package:keyboard_visibility/keyboard_visibility.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import 'search_bar_style.dart';

mixin _ControllerListener<T> on State<SearchBar<T>> {
  void onListChanged(List<T> items) {}

  void onLoading() {}

  void onClear() {}

  void onError(Error error) {}
}

enum SearchControllerStatus {
  ready,
  listChanged,
  loading,
  cleared,
  error
}

class ControllerStatusNotifier {
  ValueNotifier<SearchControllerStatus> _valueNotifier =
    ValueNotifier(SearchControllerStatus.cleared);
  void notify(SearchControllerStatus status) {
    _valueNotifier.value = status;
  }

  ValueNotifier<SearchControllerStatus> getListenable() => _valueNotifier;
}

class SearchBarController<T>{
  final List<T> _list = [];
  final List<T> _filteredList = [];
  final List<T> _sortedList = [];
  TextEditingController _searchQueryController;
  String _lastSearchedText;
  Future<List<T>> Function(String text) _lastSearchFunction;
  _ControllerListener _controllerListener;
  int Function(T a, T b) _lastSorting;
  CancelableOperation _cancelableOperation;
  int minimumChars;
  ControllerStatusNotifier statusNotifier = ControllerStatusNotifier();

  void setTextController(TextEditingController _searchQueryController, minimunChars) {
    this._searchQueryController = _searchQueryController;
    this.minimumChars = minimunChars;
  }

  void setListener(_ControllerListener _controllerListener) {
    this._controllerListener = _controllerListener;
  }

  void clear() {
    _controllerListener?.onClear();
  }

  void _search(
      String text, Future<List<T>> Function(String text) onSearch) async {
    _controllerListener?.onLoading();
    try {
      if (_cancelableOperation != null &&
          (!_cancelableOperation.isCompleted ||
              !_cancelableOperation.isCanceled)) {
        _cancelableOperation.cancel();
      }
      _cancelableOperation = CancelableOperation.fromFuture(
        onSearch(text),
        onCancel: () => {},
      );

      final List<T> items = await _cancelableOperation.value;
      _lastSearchFunction = onSearch;
      _lastSearchedText = text;
      _list.clear();
      _filteredList.clear();
      _sortedList.clear();
      _lastSorting = null;
      _list.addAll(items);
      _controllerListener?.onListChanged(_list);
    } catch (error) {
      _controllerListener?.onError(error);
    }
  }

  void injectSearch(
      String searchText, Future<List<T>> Function(String text) onSearch) {
    if (searchText != null && searchText.length >= minimumChars) {
      _searchQueryController.text = searchText;
      _search(searchText, onSearch);
    }
  }

  void replayLastSearch() {
    if (_lastSearchFunction != null && _lastSearchedText != null) {
      _search(_lastSearchedText, _lastSearchFunction);
    }
  }

  void removeFilter() {
    _filteredList.clear();
    if (_lastSorting == null) {
      _controllerListener?.onListChanged(_list);
    } else {
      _sortedList.clear();
      _sortedList.addAll(List<T>.from(_list));
      _sortedList.sort(_lastSorting);
      _controllerListener?.onListChanged(_sortedList);
    }
  }

  void removeSort() {
    _sortedList.clear();
    _lastSorting = null;
    _controllerListener
        ?.onListChanged(_filteredList.isEmpty ? _list : _filteredList);
  }

  void sortList(int Function(T a, T b) sorting) {
    _lastSorting = sorting;
    _sortedList.clear();
    _sortedList
        .addAll(List<T>.from(_filteredList.isEmpty ? _list : _filteredList));
    _sortedList.sort(sorting);
    _controllerListener?.onListChanged(_sortedList);
  }

  void filterList(bool Function(T item) filter) {
    _filteredList.clear();
    _filteredList.addAll(_sortedList.isEmpty
        ? _list.where(filter).toList()
        : _sortedList.where(filter).toList());
    _controllerListener?.onListChanged(_filteredList);
  }
}

/// Signature for a function that creates [ScaledTile] for a given index.
typedef ScaledTile IndexedScaledTileBuilder(int index);

class SearchBar<T> extends StatefulWidget {
  /// Future returning searched items
  final Future<List<T>> Function(String text) onSearch;

  /// List of items showed by default
  final List<T> suggestions;

  /// Callback returning the widget corresponding to a Suggestion item
  final Widget Function(T item, int index) buildSuggestion;

  /// Minimum number of chars required for a search
  final int minimumChars;

  /// Callback returning the widget corresponding to an item found
  final Widget Function(T item, int index) onItemFound;

  /// Callback returning the widget corresponding to an Error while searching
  final Widget Function(Error error) onError;

  /// Cooldown between each call to avoid too many
  final Duration debounceDuration;

  /// false will disable auto-searching. Must press search icon button
  final bool autoSearch;

  /// Widget to show when loading
  final Widget loader;

  /// Widget to show when no item were found
  final Widget emptyWidget;

  /// Used to set focus on search bar
  final FocusNode focusNode;

  /// Widget to show by default
  final Widget placeHolder;

  /// Widget to display results, e.g. PageView, ListView, etc. to override
  /// default StaggeredGridView.
  /// Takes an itemBuilder function which builds a widget for each item
  final Widget Function(List<T> items,
      {Widget Function(T item, int index) itemBuilder}) displayList;

  /// Builder function to use inside custom display List widget
  final Widget Function(T item, int index) displayItemBuilder;

  /// Widget showed on left of the search bar
  final Widget icon;

  /// Widget placed between the search bar and the results
  final Widget header;

  /// Hint text of the search bar
  final String hintText;

  /// TextStyle of the hint text
  final TextStyle hintStyle;

  /// Color of the icon when search bar is active
  final Color iconActiveColor;

  /// Text style of the text in the search bar
  final TextStyle textStyle;

  /// Widget shown for cancellation
  final Widget cancellationWidget;

  /// Callback when cancel button is triggered
  final VoidCallback onCancelled;

  /// Controller used to be able to sort, filter or replay the search
  final SearchBarController searchBarController;

  /// Enable to edit the style of the search bar
  final SearchBarStyle searchBarStyle;

  /// Number of items displayed on cross axis
  final int crossAxisCount;

  /// Weather the list should take the minimum place or not
  final bool shrinkWrap;

  /// Called to get the tile at the specified index for the
  /// [SliverGridStaggeredTileLayout].
  final IndexedScaledTileBuilder indexedScaledTileBuilder;

  /// Set the scrollDirection
  final Axis scrollDirection;

  /// Spacing between tiles on main axis
  final double mainAxisSpacing;

  /// Spacing between tiles on cross axis
  final double crossAxisSpacing;

  /// Set a padding on the search bar
  final EdgeInsetsGeometry searchBarPadding;

  /// Set a padding on the header
  final EdgeInsetsGeometry headerPadding;

  /// Set a padding on the list
  final EdgeInsetsGeometry listPadding;

  /// If not null, redirect searchText to this route
  final PageRoute Function(String) redirectSearchTo;

  SearchBar({
    Key key,
    @required this.onSearch,
    this.onItemFound,
    this.searchBarController,
    this.minimumChars = 3,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.autoSearch = false,
    this.loader = const Center(child: CircularProgressIndicator()),
    this.onError,
    this.emptyWidget = const SizedBox.shrink(),
    this.focusNode,
    this.header,
    this.placeHolder,
    this.displayList,
    this.displayItemBuilder,
    this.icon = const Icon(Icons.search),
    this.hintText = "",
    this.hintStyle = const TextStyle(color: Color.fromRGBO(142, 142, 147, 1)),
    this.iconActiveColor = Colors.black,
    this.textStyle = const TextStyle(color: Colors.black),
    this.cancellationWidget = const Text("Cancel"),
    this.onCancelled,
    this.suggestions = const [],
    this.buildSuggestion,
    this.searchBarStyle = const SearchBarStyle(),
    this.crossAxisCount = 1,
    this.shrinkWrap = false,
    this.indexedScaledTileBuilder,
    this.scrollDirection = Axis.vertical,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.listPadding = const EdgeInsets.all(0),
    this.searchBarPadding = const EdgeInsets.all(0),
    this.headerPadding = const EdgeInsets.all(0),
    this.redirectSearchTo
  }) : super(key: key);

  @override
  _SearchBarState createState() => _SearchBarState<T>();
}

class _SearchBarState<T> extends State<SearchBar<T>>
    with TickerProviderStateMixin, _ControllerListener<T> {
  bool _loading = false;
  Widget _error;
  final _searchQueryController = TextEditingController();
  Timer _debounce;
  bool _animate = false;
  List<T> _list = [];
  SearchBarController searchBarController;
  var keyboardVisibilityController = KeyboardVisibilityController();
  StreamSubscription keyVisSub;
  bool _keyboardVisible;
  //int _keyboardListenerId;
  bool _searchAttempted = false;

  @override
  void initState() {
    super.initState();
    searchBarController =
        widget.searchBarController ?? SearchBarController<T>();
    searchBarController.setListener(this);
    searchBarController.setTextController(_searchQueryController, widget.minimumChars);
    print('Flappy setTextController complete');
    /*_keyboardListenerId = _keyboardVisibility.addNewListener(
      onChange: (bool visible) {
        print('Keyboard Visible? $visible');
        _keyboardVisible = visible;
      }
    );*/
    keyVisSub = keyboardVisibilityController.onChange.listen((bool visible) {
      print('Keyboard Visible? $visible');
      _keyboardVisible = visible;
    });
  }

  @override
  void dispose() {
    _searchQueryController?.dispose();
    //_keyboardVisibility.removeListener(_keyboardListenerId);
    keyVisSub.cancel();
    super.dispose();
  }

  @override
  void onListChanged(List<T> items) {
    print('flappy onListChanged() setState');
    if (items.length > 0)
      searchBarController.statusNotifier.notify(SearchControllerStatus.listChanged);
    setState(() {
      _loading = false;
      _list = items;
    });
  }

  @override
  void onLoading() {
    searchBarController.statusNotifier.notify(SearchControllerStatus.loading);
    print('flappy onLoading() setState');
    setState(() {
      _loading = true;
      _error = null;
      _animate = true;
    });
  }

  void searchable() {

    // if !autoSearch, only call setState/change value if _animate == false
    if (!widget.autoSearch) {
      if (_animate == false) {
        print('flappy searchable() setState. _animate? $_animate');
        setState(() {
          _animate = true;
        });
      }
    }
    else {
      print('flappy searchable() setState. _animate? $_animate');
      setState(() {
        _animate = true;
      });
    }

  }

  void sendSearch(String newText) {
    searchBarController._search(newText, widget.onSearch);
    if (newText != null && newText.length >= widget.minimumChars) {
      _searchAttempted = true;
      print('searchBarController._search was attempted');
    }
    if (_keyboardVisible)
      FocusScope.of(context).unfocus();
  }

  @override
  void onClear() {
    _cancel();
  }

  @override
  void onError(Error error) {
    searchBarController.statusNotifier.notify(SearchControllerStatus.error);
    setState(() {
      _loading = false;
      _error = widget.onError != null ? widget.onError(error) : Text("error");
    });
  }

  void _onSubmitted(String value) {
    print('_onSubmitted: Keyboard closed with value: $value');
    if (widget.redirectSearchTo != null) {
      print('RedirectSearch not null.  Redirecting...');
      Navigator.of(context).pushAndRemoveUntil(
          widget.redirectSearchTo(value),
              (Route<dynamic> route) => false
      );
    }
    sendSearch(value);
  }

  _onTextChanged(String newText) async {
    if (newText != null && newText.length >= widget.minimumChars) {
      searchable(); // callback to show search/cancel icons near searchbar
    }

    if (_debounce?.isActive ?? false) {
      _debounce.cancel();
    }

    if (widget.autoSearch) {
      _debounce = Timer(widget.debounceDuration, () async {
        if (newText.length >= widget.minimumChars && widget.onSearch != null) {
          if (widget.autoSearch)
            searchBarController._search(newText, widget.onSearch);
        } else {
          setState(() {
            _list.clear();
            _error = null;
            _loading = false;
            _animate = false;
          });
        }
      });
    }

  }

  void _cancel() {
    if (widget.onCancelled != null) {
      widget.onCancelled();
    }

    searchBarController.statusNotifier.notify(SearchControllerStatus.cleared);

    setState(() {
      _searchQueryController.clear();
      _searchAttempted = false;
//      searchBarController.lastSearchedText = null;
      _list.clear();
      _error = null;
      _loading = false;
      _animate = false;
    });
  }

  Widget _buildListView(List<T> items, Widget Function(T item, int index) builder) {
    return Padding(
      padding: widget.listPadding,
      child: StaggeredGridView.countBuilder(
        crossAxisCount: widget.crossAxisCount,
        itemCount: items.length,
        shrinkWrap: widget.shrinkWrap,
        staggeredTileBuilder:
            widget.indexedScaledTileBuilder ?? (int index) => ScaledTile.fit(1),
        scrollDirection: widget.scrollDirection,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        addAutomaticKeepAlives: true,
        itemBuilder: (BuildContext context, int index) {
          return builder(items[index], index);
        },
      ),
    );
  }

  Widget _buildCustomListView(List<T> items,
      {Widget Function(T item, int index) itemBuilder}) {
    return Padding(
      padding: widget.listPadding,
      child: widget.displayList(items, itemBuilder: itemBuilder),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_error != null) {
      return _error;
    } else if (_loading) {
      return widget.loader;
    } else if (_list.isEmpty && _searchAttempted == false) {
      if (widget.placeHolder != null) return widget.placeHolder;
      return _buildListView(
          widget.suggestions, widget.buildSuggestion ?? widget.onItemFound);
    } else if (_list.isNotEmpty) {
      if (widget.displayList != null)
        return _buildCustomListView(_list, itemBuilder: widget.displayItemBuilder);
      return _buildListView(_list, widget.onItemFound);
    } else {
      return widget.emptyWidget;
    }
  }

  /// If redirectSearchTo constructor arg is supplied, we won't be showing results
  /// with this particular SearchBar widget instance, but redirecting to another.
  /// Only build / show the search text field when redirecting searches.
  /// When not redirecting, build / show the results of the search in _buildContent
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      print('Flappy build complete');
      searchBarController.statusNotifier.notify(SearchControllerStatus.ready);
    });
    final widthMax = MediaQuery.of(context).size.width;

    List<Widget> _columnChildren = List();
    _columnChildren.add(_searchBar(widthMax)); // always show search field

    // only build/show if not redirecting/injecting to another SearchBar
    if (widget.redirectSearchTo == null) {
      _columnChildren.add(_headerPadding());
      _columnChildren.add(_buildContentExpanded());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _columnChildren,
      /*children: <Widget>[
        Padding(
          padding: widget.searchBarPadding,
          child: Container(
            height: 80,
            padding: EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: _animate ? widthMax * .7 : widthMax,
                    decoration: BoxDecoration(
                      borderRadius: widget.searchBarStyle.borderRadius,
                      color: widget.searchBarStyle.backgroundColor,
                    ),
                    child: Padding(
                      padding: widget.searchBarStyle.padding,
                      child: Theme(
                        child: TextField(
                          controller: _searchQueryController,
                          onChanged: _onTextChanged,
                          onSubmitted: _onSubmitted,
                          style: widget.textStyle,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: widget.hintText,
                            hintStyle: widget.hintStyle,
                          ),
                        ),
                        data: Theme.of(context).copyWith(
                          primaryColor: widget.iconActiveColor,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _animate ? 1.0 : 0,
                  curve: Curves.easeIn,
                  duration: Duration(milliseconds: _animate ? 1000 : 0),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width:
                        _animate ? MediaQuery.of(context).size.width * .23 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: IconButton(
                                icon: widget.icon,
                                onPressed: () => sendSearch(_searchQueryController.text),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: IconButton(
                                icon: widget.cancellationWidget,
                                onPressed: _cancel,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: widget.headerPadding,
          child: widget.header ?? Container(),
        ),
        Expanded(
          child: _buildContent(context),
        ),
      ],*/
    );
  }

  Widget _searchBar(double widthMax) {
    return Padding(
      padding: widget.searchBarPadding,
      child: Container(
        height: 80,
        padding: EdgeInsets.only(right: 9),
        decoration: BoxDecoration(
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: _animate ? widthMax * .7 : widthMax,
                decoration: BoxDecoration(
                  borderRadius: widget.searchBarStyle.borderRadius,
                  color: widget.searchBarStyle.backgroundColor,
                ),
                child: Padding(
                  padding: widget.searchBarStyle.padding,
                  child: Theme(
                    child: TextField(
                      controller: _searchQueryController,
                      focusNode: widget.focusNode,
                      onChanged: _onTextChanged,
                      onSubmitted: _onSubmitted,
                      style: widget.textStyle,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: widget.hintStyle,
                      ),
                    ),
                    data: Theme.of(context).copyWith(
                      primaryColor: widget.iconActiveColor,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _animate ? 1.0 : 0,
              curve: Curves.easeIn,
              duration: Duration(milliseconds: _animate ? 1000 : 0),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width:
                _animate ? MediaQuery.of(context).size.width * .23 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Center(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: widget.icon,
                            onPressed: () {
                              if (widget.redirectSearchTo == null)
                                sendSearch(_searchQueryController.text);
                              else
                                Navigator.of(context).pushAndRemoveUntil(
                                    widget.redirectSearchTo(_searchQueryController.text),
                                    (Route<dynamic> route) => false
                                );
                            },
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: widget.cancellationWidget,
                            onPressed: _cancel,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerPadding() {
    return Padding(
      padding: widget.headerPadding,
      child: widget.header ?? Container(),
    );
  }

  Widget _buildContentExpanded() {
    return Expanded(
      child: _buildContent(context),
    );
  }
}
