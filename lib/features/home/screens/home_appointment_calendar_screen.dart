import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/appointment_model.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../counseling/screens/pacc_counseling_screen.dart';
import '../../counseling/widgets/appointment_details_sheet.dart';
import '../widgets/home_dashboard_widgets.dart';

class HomeAppointmentCalendarScreen extends StatefulWidget {
  const HomeAppointmentCalendarScreen({
    super.key,
    this.initialDate,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime? initialDate;
  final DateTime Function() _nowProvider;

  @override
  State<HomeAppointmentCalendarScreen> createState() =>
      _HomeAppointmentCalendarScreenState();
}

class _HomeAppointmentCalendarScreenState
    extends State<HomeAppointmentCalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(
      widget.initialDate ?? widget._nowProvider(),
    );
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = _currentUserId();
    final provider = _readProvider<AppointmentProvider>();
    if (userId == null || provider == null || _loadedUserId == userId) return;
    _loadedUserId = userId;
    if (provider.loadedUserId == userId && provider.appointments.isNotEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.loadAppointments(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _watchProvider<AppointmentProvider>();
    final appointments = provider?.appointments ?? const <AppointmentModel>[];
    final selectedAppointments =
        appointments
            .where(
              (item) => isSameAppointmentDate(item.scheduledAt, _selectedDate),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final userId = _currentUserId();

    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        title: const Text('Appointment Calendar'),
        backgroundColor: HomePalette.sun,
        foregroundColor: HomePalette.text,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
        children: [
          if (userId == null)
            const _CalendarMessage(
              icon: Icons.lock_outline,
              title: 'Sign in to view appointments',
              message:
                  'Your counseling schedule will appear here after you sign in.',
            )
          else ...[
            _MonthCalendar(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              appointments: appointments,
              onDateSelected: (date) => setState(() => _selectedDate = date),
              onPrevious: () => setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              }),
              onNext: () => setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                );
              }),
              onToday: _goToToday,
            ),
            const SizedBox(height: 18),
            if (provider?.isLoading == true && appointments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (provider?.errorMessage != null && appointments.isEmpty)
              _CalendarMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load appointments',
                message: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => provider?.loadAppointments(userId),
              )
            else ...[
              if (provider?.errorMessage != null)
                _CachedWarning(
                  onRetry: () => provider?.loadAppointments(userId),
                ),
              _SelectedDayAgenda(
                date: _selectedDate,
                appointments: selectedAppointments,
                onAppointmentTap: (item) =>
                    showAppointmentDetailsSheet(context, item),
                onBook: _openBooking,
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _goToToday() {
    final today = DateUtils.dateOnly(widget._nowProvider());
    setState(() {
      _selectedDate = today;
      _visibleMonth = DateTime(today.year, today.month);
    });
  }

  void _openBooking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PaccCounselingScreen(startBooking: true),
      ),
    );
  }

  String? _currentUserId() {
    final auth = _readProvider<AuthProvider>();
    final authId = auth?.userId ?? auth?.hydrateCurrentUser();
    if (authId != null && authId.isNotEmpty) return authId;
    final profileId = _readProvider<UserProvider>()?.user?.id;
    return profileId == null || profileId.isEmpty ? null : profileId;
  }

  T? _readProvider<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  T? _watchProvider<T>() {
    try {
      return context.watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.appointments,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<AppointmentModel> appointments;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final leading = first.weekday % 7;
    final days = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final cells = leading + days;
    final rows = (cells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HomeDecor.card(borderColor: const Color(0xFFE7D69A)),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${months[visibleMonth.month - 1]} ${visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: HomeTextStyles.sectionTitle,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          TextButton(onPressed: onToday, child: const Text('Today')),
          Row(
            children: [
              for (final day in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(day, style: HomeTextStyles.caption),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: rows > 5 ? 49 : 54,
            ),
            itemCount: rows * 7,
            itemBuilder: (_, index) {
              final day = index - leading + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(visibleMonth.year, visibleMonth.month, day);
              final dayAppointments = appointments
                  .where(
                    (item) => isSameAppointmentDate(item.scheduledAt, date),
                  )
                  .toList();
              return _CalendarDay(
                date: date,
                selected: isSameAppointmentDate(date, selectedDate),
                appointments: dayAppointments,
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.selected,
    required this.appointments,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final List<AppointmentModel> appointments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statuses = appointments
        .map((item) => appointmentDisplayStatus(item.status))
        .toSet()
        .take(3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? HomePalette.softGold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: HomePalette.gold) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (appointments.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final status in statuses)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: appointmentStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (appointments.length > 1)
                    Text(
                      '${appointments.length}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedDayAgenda extends StatelessWidget {
  const _SelectedDayAgenda({
    required this.date,
    required this.appointments,
    required this.onAppointmentTap,
    required this.onBook,
  });
  final DateTime date;
  final List<AppointmentModel> appointments;
  final ValueChanged<AppointmentModel> onAppointmentTap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatAppointmentDate(date), style: HomeTextStyles.sectionTitle),
        const SizedBox(height: 12),
        if (appointments.isEmpty)
          _CalendarMessage(
            icon: Icons.event_available_outlined,
            title: 'No appointments on this date',
            message:
                'Choose another date or schedule a counseling appointment.',
            actionLabel: 'Book appointment',
            onAction: onBook,
          )
        else
          for (final item in appointments) ...[
            _AgendaCard(appointment: item, onTap: () => onAppointmentTap(item)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.appointment, required this.onTap});
  final AppointmentModel appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = appointmentDisplayStatus(appointment.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: HomeDecor.card(
            borderColor: appointmentStatusColor(status).withValues(alpha: .4),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 54,
                decoration: BoxDecoration(
                  color: appointmentStatusColor(status),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.scheduledTime,
                      style: HomeTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(appointment.location, style: HomeTextStyles.bodyMuted),
                    Text(
                      appointment.status,
                      style: TextStyle(
                        color: appointmentStatusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        decoration: status == AppointmentDisplayStatus.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarMessage extends StatelessWidget {
  const _CalendarMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: HomeDecor.card(),
    child: Column(
      children: [
        Icon(icon, size: 34, color: HomePalette.gold),
        const SizedBox(height: 9),
        Text(
          title,
          textAlign: TextAlign.center,
          style: HomeTextStyles.cardTitle,
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: HomeTextStyles.bodyMuted,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _CachedWarning extends StatelessWidget {
  const _CachedWarning({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Showing saved appointments. Refresh failed.',
            style: HomeTextStyles.bodyMuted,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
