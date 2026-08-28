import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'wedding_music_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await _initializeFirebase();
  runApp(InvitationApp(firebaseReady: firebaseReady));
}

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'invitation bootstrap',
      ),
    );
    return false;
  }
}

class InvitationApp extends StatelessWidget {
  const InvitationApp({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final inter = GoogleFonts.interTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '${InvitationContent.groom} & ${InvitationContent.bride}',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.cream,
        textTheme: inter.apply(
          bodyColor: AppColors.charcoal,
          displayColor: AppColors.charcoal,
        ),
        useMaterial3: true,
      ),
      home: InvitationPage(firebaseReady: firebaseReady),
    );
  }
}

class InvitationContent {
  static const groom = 'Fozil';
  static const bride = 'Dilafruz';
  static const inviteLine = 'Sizni taklif etamiz!';
  static const quote =
      '"Muhabbat - bu ikki yulduzning bir osmonda uchrashishi"';
  static const dateText = '8 Sentabr, 2026';
  static const weekDay = 'Seshanba';
  static const dayAndMonth = '8-Sentabr';
  static const timeText = 'Soat 18:00 da';
  static const venueName = '"Murod Fayz" Restorani ';
  static const venueAddress = 'Buxoro shahar 6-mikrayon ';
  static const googleMap = 'https://maps.app.goo.gl/fRRqZjoH4pH7T9oD8';
  static const yandexMap = 'https://yandex.uz/maps/-/CTDLQRnG';

  static final weddingDate = DateTime(2026, 9, 8, 18);
}

class AppColors {
  static const cream = Color(0xFFFAF9F6);
  static const warmBand = Color(0xFFF2EFEB);
  static const card = Color(0xFFFFFFFF);
  static const input = Color(0xFFFCFBF9);
  static const accent = Color(0xFF966E52);
  static const burgundy = Color(0xFF3B0712);
  static const introGold = Color(0xFFE5B85A);
  static const accentSoft = Color(0xFFF1ECE7);
  static const charcoal = Color(0xFF3F3A37);
  static const muted = Color(0xFF8F8A86);
  static const faint = Color(0xFFEAE5DE);
  static const warningBg = Color(0xFFFFF8E5);
  static const warningText = Color(0xFF9B6A42);
}

class InvitationPage extends StatefulWidget {
  const InvitationPage({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  final _musicPlayer = WeddingMusicPlayer();
  final _scrollController = ScrollController(initialScrollOffset: 1);

  bool _musicPlaying = false;
  bool _gestureMusicFallbackEnabled = true;
  bool _gestureMusicAttempted = false;
  bool _snappingToSection = false;
  ScrollDirection _lastScrollDirection = ScrollDirection.idle;
  Timer? _autoplayRetryTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_keepTelegramWebViewOpen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepTelegramWebViewOpen();
      _scheduleAutoplay();
    });
  }

  @override
  void dispose() {
    _autoplayRetryTimer?.cancel();
    _scrollController.dispose();
    _musicPlayer.dispose();
    super.dispose();
  }

  void _keepTelegramWebViewOpen() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 && position.pixels <= 0) {
      _scrollController.jumpTo(1);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      _lastScrollDirection = notification.direction;
    }

    if (notification is ScrollEndNotification) {
      _snapToPrimarySection();
    }

    return false;
  }

  void _snapToPrimarySection() {
    if (!_scrollController.hasClients || _snappingToSection) {
      return;
    }

    final sectionExtent = sectionHeight(context);
    if (sectionExtent <= 0) {
      return;
    }

    final position = _scrollController.position;
    final currentOffset = position.pixels;

    if (currentOffset > sectionExtent * 1.2) {
      return;
    }

    final page = currentOffset / sectionExtent;
    final targetIndex = switch (_lastScrollDirection) {
      ScrollDirection.reverse => 1,
      ScrollDirection.forward => page < 0.82 ? 0 : 1,
      ScrollDirection.idle => page.round(),
    }.clamp(0, 1).toInt();
    final rawTarget = targetIndex == 0 ? 1.0 : sectionExtent;
    final target = rawTarget.clamp(0.0, position.maxScrollExtent);

    if ((currentOffset - target).abs() < 2) {
      return;
    }

    _snappingToSection = true;
    unawaited(
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted) {
              return;
            }
            _snappingToSection = false;
            _lastScrollDirection = ScrollDirection.idle;
            _keepTelegramWebViewOpen();
          }),
    );
  }

  void _scheduleAutoplay() {
    _startMusic();

    var attempts = 0;
    _autoplayRetryTimer = Timer.periodic(const Duration(milliseconds: 700), (
      timer,
    ) {
      if (_musicPlaying || attempts >= 5) {
        timer.cancel();
        return;
      }

      attempts++;
      _startMusic();
    });
  }

  void _startMusic({bool restart = false, bool userGesture = false}) {
    unawaited(
      _musicPlayer.play(restart: restart, userGesture: userGesture).then((
        isPlaying,
      ) {
        if (isPlaying) {
          _gestureMusicFallbackEnabled = false;
          _autoplayRetryTimer?.cancel();
        }
        if (mounted) {
          setState(() => _musicPlaying = isPlaying);
        }
      }),
    );
  }

  void _startMusicFromGesture() {
    if (!_gestureMusicFallbackEnabled ||
        _gestureMusicAttempted ||
        _musicPlaying) {
      return;
    }

    _gestureMusicAttempted = true;
    _startMusic(userGesture: true);
  }

  void _toggleMusic() {
    _gestureMusicFallbackEnabled = false;
    _autoplayRetryTimer?.cancel();
    unawaited(
      _musicPlayer.toggle().then((isPlaying) {
        if (mounted) {
          setState(() => _musicPlaying = isPlaying);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.cream),
        child: Stack(
          children: [
            const Positioned.fill(child: TwinklingStarBackground()),
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _startMusicFromGesture(),
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: ScrollRevealScope(
                  enabled: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        const MainInvitationFlow(),
                        WishesSection(firebaseReady: widget.firebaseReady),
                        const ClosingSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: compact ? 14 : 22,
              bottom: compact ? 14 : 22,
              child: SafeArea(
                child: MusicToggleButton(
                  isPlaying: _musicPlaying,
                  onPressed: _toggleMusic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicToggleButton extends StatelessWidget {
  const MusicToggleButton({
    required this.isPlaying,
    required this.onPressed,
    super.key,
  });

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.86),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: isPlaying ? 'Musiqani to\'xtatish' : 'Musiqani yoqish',
        color: AppColors.introGold,
        icon: Icon(
          isPlaying ? Icons.music_note : Icons.music_off_outlined,
          size: 22,
        ),
      ),
    );
  }
}

class TwinklingStarBackground extends StatefulWidget {
  const TwinklingStarBackground({super.key});

  @override
  State<TwinklingStarBackground> createState() =>
      _TwinklingStarBackgroundState();
}

class _TwinklingStarBackgroundState extends State<TwinklingStarBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: TwinklingStarPainter(time: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class TwinklingStarPainter extends CustomPainter {
  const TwinklingStarPainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(73);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dotCount = size.width < 600 ? 44 : 88;
    final plusCount = size.width < 600 ? 6 : 12;

    for (var i = 0; i < dotCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final pulse =
          0.55 + 0.45 * math.sin(time * math.pi * 2 + random.nextDouble() * 9);
      final radius = 0.7 + random.nextDouble() * 1.25;
      final starColor = Color.lerp(
        const Color(0xFF8F6432),
        AppColors.introGold,
        random.nextDouble() * 0.35,
      )!;
      final alpha = (0.22 + pulse * 0.34).clamp(0.0, 0.56).toDouble();

      dotPaint.color = starColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }

    for (var i = 0; i < plusCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final pulse =
          0.4 + 0.6 * math.sin(time * math.pi * 2 + random.nextDouble() * 11);
      final length = 2.8 + random.nextDouble() * 3.4;
      final paint = Paint()
        ..strokeWidth = 0.75
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFFCBA25B,
        ).withValues(alpha: (0.1 + pulse * 0.16).clamp(0.0, 0.26).toDouble());

      canvas.drawLine(Offset(x - length, y), Offset(x + length, y), paint);
      canvas.drawLine(Offset(x, y - length), Offset(x, y + length), paint);
    }
  }

  @override
  bool shouldRepaint(TwinklingStarPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class ScrollRevealScope extends InheritedWidget {
  const ScrollRevealScope({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ScrollRevealScope>()
            ?.enabled ??
        true;
  }

  @override
  bool updateShouldNotify(ScrollRevealScope oldWidget) {
    return oldWidget.enabled != enabled;
  }
}

class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 820),
    this.yOffset = 0.16,
    this.trigger = 0.82,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double yOffset;
  final double trigger;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  ScrollPosition? _scrollPosition;
  Timer? _delayTimer;
  bool _revealed = false;
  bool _scopeEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.yOffset),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = ScrollRevealScope.enabledOf(context);
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (nextPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_checkVisibility);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _scrollPosition?.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  void _checkVisibility() {
    if (!mounted || _revealed || !_scopeEnabled) {
      return;
    }

    final context = _contentKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return;
    }

    final viewportHeight = MediaQuery.sizeOf(this.context).height;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final isVisible =
        bottom > viewportHeight * 0.04 && top < viewportHeight * widget.trigger;

    if (isVisible) {
      _reveal();
    }
  }

  void _reveal() {
    if (_revealed) {
      return;
    }

    _revealed = true;
    _scrollPosition?.removeListener(_checkVisibility);
    if (widget.delay == Duration.zero) {
      unawaited(_controller.forward());
      return;
    }

    _delayTimer = Timer(widget.delay, () {
      if (mounted) {
        unawaited(_controller.forward());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _contentKey,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _offset, child: widget.child),
      ),
    );
  }
}

class MainInvitationFlow extends StatelessWidget {
  const MainInvitationFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HeroScreenSection(),
        DetailsScreenSection(),
        CountdownScreenSection(),
      ],
    );
  }
}

class HeroScreenSection extends StatelessWidget {
  const HeroScreenSection({super.key});

  @override
  Widget build(BuildContext context) {
    final height = sectionHeight(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final pagePadding = horizontalPagePadding(context);
    final contentWidth = math.min(
      560.0,
      math.max(260.0, size.width - pagePadding * 2),
    );

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(width: contentWidth, child: const InvitationHero()),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: compact ? 24 : 42,
            child: Center(child: VerticalThread(height: compact ? 70 : 96)),
          ),
        ],
      ),
    );
  }
}

class InvitationHero extends StatelessWidget {
  const InvitationHero({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final tightHeight = size.height < 720;
    final nameSize = width < 360
        ? 50.0
        : width < 600
        ? 58.0
        : width < 760
        ? 78.0
        : 88.0;
    final verseSize = width < 360
        ? 20.0
        : width < 600
        ? 23.0
        : 28.0;
    final topGap = tightHeight
        ? 34.0
        : width < 600
        ? 46.0
        : 60.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrollReveal(
          delay: const Duration(milliseconds: 80),
          trigger: 2,
          child: Text(
            '✦   وَخَلَقْنَاكُمْ أَزْوَاجًا   ✦',
            textAlign: TextAlign.center,
            style: overlineStyle(context).copyWith(
              color: AppColors.accent.withValues(alpha: 0.62),
              fontSize: verseSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ScrollReveal(
          delay: const Duration(milliseconds: 150),
          trigger: 2,
          child: Text(
            'Va sizlarni juft qilib yaratdik.\n ("Naba" surasi 8-oyat)',
            textAlign: TextAlign.center,
            style: overlineStyle(context).copyWith(
              color: AppColors.accent.withValues(alpha: 0.62),
              fontSize: width < 600 ? 12 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: topGap),
        ScrollReveal(
          delay: const Duration(milliseconds: 260),
          yOffset: 0.12,
          trigger: 2,
          child: HeroNameText(text: InvitationContent.groom, size: nameSize),
        ),
        ScrollReveal(
          delay: const Duration(milliseconds: 340),
          trigger: 2,
          child: Text(
            'va',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.accent.withValues(alpha: 0.72),
              fontSize: 20,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ScrollReveal(
          delay: const Duration(milliseconds: 420),
          yOffset: 0.12,
          trigger: 2,
          child: HeroNameText(text: InvitationContent.bride, size: nameSize),
        ),
        SizedBox(height: width < 600 ? 20 : 26),
        const ScrollReveal(
          delay: Duration(milliseconds: 520),
          trigger: 2,
          child: HeartDivider(width: 152),
        ),
        SizedBox(height: width < 600 ? 22 : 28),
        ScrollReveal(
          delay: const Duration(milliseconds: 610),
          trigger: 2,
          child: Text(
            InvitationContent.inviteLine,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.charcoal.withValues(alpha: 0.76),
              fontSize: width < 600 ? 19 : 21,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: width < 600 ? 18 : 24),
        ScrollReveal(
          delay: const Duration(milliseconds: 700),
          trigger: 2,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width < 600 ? 252 : 330),
            child: Text(
              InvitationContent.quote,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.charcoal.withValues(alpha: 0.68),
                fontSize: width < 600 ? 14 : 16,
                height: 1.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(height: width < 600 ? 26 : 34),
        ScrollReveal(
          delay: const Duration(milliseconds: 790),
          trigger: 2,
          child: Text(
            InvitationContent.dateText,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.accent.withValues(alpha: 0.86),
              fontSize: width < 600 ? 22 : 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class HeroNameText extends StatelessWidget {
  const HeroNameText({required this.text, required this.size, super.key});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width -
                  horizontalPagePadding(context) * 2;

        return SizedBox(
          width: maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: heroNameStyle(size),
            ),
          ),
        );
      },
    );
  }
}

class DetailsScreenSection extends StatelessWidget {
  const DetailsScreenSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPagePadding(context),
        compact ? 38 : 54,
        horizontalPagePadding(context),
        compact ? 30 : 42,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScrollReveal(child: VerticalThread(height: compact ? 54 : 70)),
            SizedBox(height: compact ? 30 : 38),
            const DetailCards(),
          ],
        ),
      ),
    );
  }
}

class DetailCards extends StatelessWidget {
  const DetailCards({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        children: [
          const ScrollReveal(
            child: InfoCard(
              title: 'Qachon',
              children: [
                IconInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'SANA',
                  value:
                      '${InvitationContent.weekDay}, '
                      '${InvitationContent.dayAndMonth}',
                ),
                SizedBox(height: 22),
                IconInfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'VAQT',
                  value: InvitationContent.timeText,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 22 : 24),
          const ScrollReveal(
            delay: Duration(milliseconds: 170),
            child: InfoCard(
              title: 'Manzil',
              children: [
                IconInfoRow(
                  icon: Icons.location_on_outlined,
                  value: InvitationContent.venueName,
                  label: InvitationContent.venueAddress,
                  labelBelow: true,
                ),
                SizedBox(height: 30),
                MapButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 22 : 28,
        compact ? 24 : 28,
        compact ? 22 : 28,
        compact ? 26 : 30,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.charcoal,
              fontSize: compact ? 22 : 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 24 : 28),
          ...children,
        ],
      ),
    );
  }
}

class IconInfoRow extends StatelessWidget {
  const IconInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.labelBelow = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool labelBelow;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: compact ? 19 : 21,
          backgroundColor: AppColors.accentSoft,
          child: Icon(icon, color: AppColors.accent, size: compact ? 18 : 20),
        ),
        SizedBox(width: compact ? 16 : 20),
        Expanded(
          child: labelBelow
              ? _LocationText(label: label, value: value)
              : _DateText(label: label, value: value),
        ),
      ],
    );
  }
}

class _DateText extends StatelessWidget {
  const _DateText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: overlineStyle(context)),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LocationText extends StatelessWidget {
  const _LocationText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class MapButtons extends StatelessWidget {
  const MapButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          MapButton(
            label: 'Google Xarita',
            url: InvitationContent.googleMap,
            filled: true,
          ),
          SizedBox(height: 12),
          MapButton(label: 'Yandex Xarita', url: InvitationContent.yandexMap),
        ],
      );
    }

    return Row(
      children: const [
        Expanded(
          child: MapButton(
            label: 'Google Xarita',
            url: InvitationContent.googleMap,
            filled: true,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: MapButton(
            label: 'Yandex Xarita',
            url: InvitationContent.yandexMap,
          ),
        ),
      ],
    );
  }
}

class MapButton extends StatelessWidget {
  const MapButton({
    required this.label,
    required this.url,
    this.filled = false,
    super.key,
  });

  final String label;
  final String url;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(46)),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: WidgetStateProperty.all(
        Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    if (filled) {
      return FilledButton(
        onPressed: () => openExternalUrl(context, url),
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.all(AppColors.accent),
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: () => openExternalUrl(context, url),
      style: style.copyWith(
        foregroundColor: WidgetStateProperty.all(AppColors.accent),
        side: WidgetStateProperty.all(
          const BorderSide(color: AppColors.accent),
        ),
      ),
      child: Text(label),
    );
  }
}

class CountdownScreenSection extends StatelessWidget {
  const CountdownScreenSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPagePadding(context),
        compact ? 38 : 54,
        horizontalPagePadding(context),
        compact ? 58 : 74,
      ),
      child: const Center(child: CountdownSection()),
    );
  }
}

class CountdownSection extends StatefulWidget {
  const CountdownSection({super.key});

  @override
  State<CountdownSection> createState() => _CountdownSectionState();
}

class _CountdownSectionState extends State<CountdownSection> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _remaining = _calculateRemaining());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final value = InvitationContent.weddingDate.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final items = [
      CountdownItem(_remaining.inDays, 'KUN'),
      CountdownItem(_remaining.inHours.remainder(24), 'SOAT'),
      CountdownItem(_remaining.inMinutes.remainder(60), 'MIN'),
      CountdownItem(_remaining.inSeconds.remainder(60), 'SEK'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrollReveal(
          child: Text(
            'To\'ygacha qolgan vaqt',
            textAlign: TextAlign.center,
            style: sectionTitleStyle(context),
          ),
        ),
        SizedBox(height: compact ? 24 : 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final spacing = compact ? 8.0 : 22.0;
            final boxWidth = compact
                ? math.max(
                    52.0,
                    math.min(72.0, (availableWidth - spacing * 3) / 4),
                  )
                : 92.0;
            final boxHeight = compact ? boxWidth * 1.24 : 108.0;
            final valueFontSize = compact
                ? math.max(24.0, math.min(32.0, boxWidth * 0.45))
                : 36.0;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) SizedBox(width: spacing),
                  ScrollReveal(
                    delay: Duration(milliseconds: 120 + index * 90),
                    yOffset: 0.18,
                    child: CountdownBox(
                      value: items[index].value,
                      label: items[index].label,
                      boxWidth: boxWidth,
                      boxHeight: boxHeight,
                      valueFontSize: valueFontSize,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class CountdownItem {
  const CountdownItem(this.value, this.label);

  final int value;
  final String label;
}

class CountdownBox extends StatelessWidget {
  const CountdownBox({
    required this.value,
    required this.label,
    this.boxWidth,
    this.boxHeight,
    this.valueFontSize,
    super.key,
  });

  final int value;
  final String label;
  final double? boxWidth;
  final double? boxHeight;
  final double? valueFontSize;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final width = boxWidth ?? (compact ? 78.0 : 92.0);
    final height = boxHeight ?? (compact ? 92.0 : 108.0);
    final fontSize = valueFontSize ?? (compact ? 32.0 : 36.0);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 26,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Text(
              value.toString().padLeft(2, '0'),
              style: GoogleFonts.playfairDisplay(
                color: AppColors.accent,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 15),
          Text(label, style: overlineStyle(context)),
        ],
      ),
    );
  }
}

class WishesSection extends StatefulWidget {
  const WishesSection({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<WishesSection> createState() => _WishesSectionState();
}

class _WishesSectionState extends State<WishesSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  CollectionReference<Map<String, dynamic>>? _responses;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.firebaseReady) {
      return;
    }

    try {
      _responses = FirebaseFirestore.instance.collection('wedding_responses');
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'wishes section',
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final responses = _responses;
    if (responses == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tilaklar hozircha ulanmadi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await responses.add({
        'name': _nameController.text.trim(),
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      _nameController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tilagingiz yuborildi.')));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Firebase bilan ulanishda xatolik yuz berdi.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final responses = _responses;

    return ColoredBox(
      color: AppColors.warmBand,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: sectionHeight(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPagePadding(context),
                compact ? 62 : 82,
                horizontalPagePadding(context),
                compact ? 88 : 118,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // const ScrollReveal(child: SyncBadge()),
                  SizedBox(height: compact ? 8 : 18),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 110),
                    child: Text(
                      'Tilaklar va Izohlar',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.accent,
                        fontSize: compact ? 27 : 31,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 14),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Barcha mehmonlarimizning tilaklarini shu yerda '
                      'ko\'rishingiz mumkin',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 34 : 46),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 310),
                    yOffset: 0.11,
                    child: WishesForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      messageController: _messageController,
                      isSubmitting: _isSubmitting,
                      onSubmit: _submit,
                    ),
                  ),
                  SizedBox(height: compact ? 44 : 58),
                  if (responses == null)
                    const ScrollReveal(
                      delay: Duration(milliseconds: 440),
                      child: InlineWarning(
                        text: 'Tilaklar bo\'limi hozircha ulanmadi.',
                      ),
                    )
                  else
                    ScrollReveal(
                      delay: const Duration(milliseconds: 440),
                      child: WishesList(responses: responses),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.faint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 13,
            color: AppColors.accent.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 7),
          Text(
            'FIREBASE CLOUD SYNC',
            style: overlineStyle(context).copyWith(
              color: AppColors.accent.withValues(alpha: 0.78),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class WishesForm extends StatelessWidget {
  const WishesForm({
    required this.formKey,
    required this.nameController,
    required this.messageController,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController messageController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ISMINGIZ', style: overlineStyle(context)),
            const SizedBox(height: 10),
            TextFormField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: softInputDecoration(
                hint: 'Ismingizni kiriting',
                icon: Icons.person_outline,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Ismingizni kiriting';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            Text('TILAGINGIZ', style: overlineStyle(context)),
            const SizedBox(height: 10),
            TextFormField(
              controller: messageController,
              minLines: compact ? 4 : 5,
              maxLines: compact ? 7 : 8,
              decoration: softInputDecoration(
                hint: 'O\'z tilaklaringizni shu yerda qoldiring...',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Qisqa tilak yozing';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.62),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(
                  alpha: 0.32,
                ),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.near_me_outlined, size: 18),
              label: Text(
                isSubmitting ? 'YUBORILMOQDA' : 'YUBORISH',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WishesList extends StatelessWidget {
  const WishesList({required this.responses, super.key});

  final CollectionReference<Map<String, dynamic>> responses;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: responses
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InlineWarning(
            text:
                'Ma\'lumotlar bazasi bilan muammo: '
                '${snapshot.error}. Firebase sozlamalarini tekshiring.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 42,
            width: 42,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text(
            'Hozircha tilaklar yo\'q. Birinchilardan bo\'lib yozing!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
              fontStyle: FontStyle.italic,
            ),
          );
        }

        return Column(
          children: [
            for (final doc in docs) ...[
              WishTile(data: doc.data()),
              if (doc != docs.last) const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class InlineWarning extends StatelessWidget {
  const InlineWarning({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE4A8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningText,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WishTile extends StatelessWidget {
  const WishTile({required this.data, super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?)?.trim();
    final message = (data['message'] as String?)?.trim();
    final createdAt = data['createdAt'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: AppColors.accent.withValues(alpha: 0.72),
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name?.isNotEmpty == true ? name! : 'Mehmon',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (createdAt is Timestamp)
                Text(
                  formatDate(createdAt.toDate()),
                  style: overlineStyle(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message?.isNotEmpty == true ? message! : 'Samimiy tilaklar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class ClosingSection extends StatelessWidget {
  const ClosingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ColoredBox(
      color: AppColors.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: sectionHeight(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPagePadding(context),
                compact ? 70 : 86,
                horizontalPagePadding(context),
                compact ? 70 : 82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ScrollReveal(child: HeartDivider(width: 380)),
                  SizedBox(height: compact ? 26 : 32),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 130),
                    child: Text(
                      'Sizni kutamiz!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.accent,
                        fontSize: compact ? 27 : 30,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 24),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 240),
                    child: Text(
                      'Biz quvonchli kunimizni siz bilan birga nishonlashdan '
                      'juda mamnunmiz. Bizning hayot yo\'limizning bir bo\'lagi '
                      'bo\'lganingiz uchun rahmat.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.55,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 22 : 26),
                  ScrollReveal(
                    delay: const Duration(milliseconds: 350),
                    child: Text(
                      '${InvitationContent.groom} & ${InvitationContent.bride}',
                      textAlign: TextAlign.center,
                      style: overlineStyle(
                        context,
                      ).copyWith(color: AppColors.accent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HeartDivider extends StatelessWidget {
  const HeartDivider({required this.width, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width;
        final dividerWidth = math.min(width, availableWidth);

        return SizedBox(
          width: dividerWidth,
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppColors.faint)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.favorite,
                  color: AppColors.accent.withValues(alpha: 0.9),
                  size: 14,
                ),
              ),
              const Expanded(child: Divider(color: AppColors.faint)),
            ],
          ),
        );
      },
    );
  }
}

class VerticalThread extends StatelessWidget {
  const VerticalThread({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      color: AppColors.faint,
      margin: const EdgeInsets.only(bottom: 10),
    );
  }
}

TextStyle heroNameStyle(double size) {
  return GoogleFonts.playfairDisplay(
    color: AppColors.accent,
    fontSize: size,
    height: 0.98,
    fontWeight: FontWeight.w700,
  );
}

TextStyle sectionTitleStyle(BuildContext context) {
  return GoogleFonts.playfairDisplay(
    color: AppColors.charcoal.withValues(alpha: 0.86),
    fontSize: MediaQuery.sizeOf(context).width < 600 ? 29 : 34,
    height: 1.1,
    fontWeight: FontWeight.w600,
  );
}

TextStyle overlineStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall!.copyWith(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
  );
}

InputDecoration softInputDecoration({required String hint, IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAFA9A3), fontSize: 14),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: AppColors.muted.withValues(alpha: 0.72), size: 18),
    filled: true,
    fillColor: AppColors.input,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.28)),
    ),
  );
}

double horizontalPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 360) {
    return 16;
  }
  if (width < 390) {
    return 18;
  }
  if (width < 640) {
    return 26;
  }
  return 0;
}

double sectionHeight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final minimum = switch (size.width) {
    < 360 => 760.0,
    < 600 => 790.0,
    < 760 => 840.0,
    _ => 900.0,
  };
  return math.max(size.height, minimum);
}

double intervalValue(double value, double start, double end, Curve curve) {
  final normalized = ((value - start) / (end - start))
      .clamp(0.0, 1.0)
      .toDouble();
  return curve.transform(normalized);
}

String formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Havola ochilmadi.')));
}
