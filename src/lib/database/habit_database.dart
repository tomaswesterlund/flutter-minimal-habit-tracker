import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:minimal_habit_tracker/models/app_settings.dart';
import 'package:minimal_habit_tracker/models/habit.dart';
import 'package:path_provider/path_provider.dart';

class HabitDatabase extends ChangeNotifier {
  static late Isar isar;

  // Initialize database
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar =
        await Isar.open([HabitSchema, AppSettingsSchema], directory: dir.path);
  }

  // Save first date of app startup (for heatmap)
  Future<void> saveFirstLaunchDate() async {
    final existingSettings = await isar.appSettings.where().findFirst();
    if (existingSettings == null) {
      final settings = AppSettings()..firstLaunchDate = DateTime.now();
      await isar.writeTxn(() => isar.appSettings.put(settings));
    }
  }

  // Get first date of app startup (for heatmap)
  Future<DateTime?> getFirstLaunchDate() async {
    final settings = await isar.appSettings.where().findFirst();
    return settings?.firstLaunchDate;
  }

  // *** CRUD *** //

  // List of habits
  final List<Habit> currentHabits = [];

  // CREATE - Add a new habit
  Future<void> addHabit(String habitName) async {
    final habit = Habit()..name = habitName;
    await isar.writeTxn(() => isar.habits.put(habit));

    // Updates habit list and notifies listeners
    readHabits();
  }

  // READ - Read all habits
  Future<void> readHabits() async {
    List<Habit> fetchedHabits = await isar.habits.where().findAll();

    currentHabits.clear();
    currentHabits.addAll(fetchedHabits);

    notifyListeners();
  }

  // UPDATE - Check habit on and off
  Future<void> updateHabitCompletion(int id, bool isCompleted) async {
    final habit = await isar.habits.get(id);

    if (habit != null) {
      await isar.writeTxn(
        () async {
          // If habit is completed -> Add the current date to completedDays list
          if (isCompleted && !habit.completedDays.contains(DateTime.now())) {
            final today = DateTime.now();

            habit.completedDays.add(
              DateTime(today.year, today.month, today.day),
            );
          }
          // If habit is NOT completed -> Remove the current date from the list
          else {
            habit.completedDays.removeWhere((date) =>
                date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day);
          }

          await isar.habits.put(habit);
        },
      );
    }

    readHabits();
  }

  // UPDATE - Update habit name
  Future<void> updateHabitName(int id, String newName) async {
    final habit = await isar.habits.get(id);

    if(habit != null) {
      await isar.writeTxn(() async {
        habit.name = newName;
        await isar.habits.put(habit);
      });
    }

    readHabits();
  }

  // DELETE - Delete habit
  Future<void> deleteHabit(int id) async {
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });

    readHabits();
  }
}
