// ABOUTME: JSON converters for Duration stored as an integer number of minutes.
// ABOUTME: Shared by RaceConfig.duration and PlanEntry.timeMark @JsonKey annotations.

Duration durationFromJson(int minutes) => Duration(minutes: minutes);
int durationToJson(Duration duration) => duration.inMinutes;
