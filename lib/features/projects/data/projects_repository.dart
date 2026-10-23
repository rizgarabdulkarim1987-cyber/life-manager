import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../ai/planner.dart';

class ProjectsRepository {
  ProjectsRepository(this._db);

  final AppDatabase _db;

  DateTime get _now => DateTime.now().toUtc();

  Future<int> create({required String title, String? description, String status = 'idea', int? captureId}) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title');
    return _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            title: t,
            description: Value(description?.trim().isEmpty ?? true ? null : description!.trim()),
            status: Value(status),
            captureId: Value(captureId),
            createdAt: _now,
            updatedAt: _now,
          ),
        );
  }

  Future<Project?> get(int id) => (_db.select(_db.projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<Project?> watch(int id) => (_db.select(_db.projects)..where((p) => p.id.equals(id))).watchSingleOrNull();

  /// Open projects first (newest edit on top), finished and dropped ones after.
  Stream<List<Project>> watchAll() =>
      (_db.select(_db.projects)..orderBy([
            (p) => OrderingTerm.asc(CustomExpression<int>("CASE WHEN status IN ('done','dropped') THEN 1 ELSE 0 END")),
            (p) => OrderingTerm.desc(p.updatedAt),
          ]))
          .watch();

  Future<List<Project>> all() => _db.select(_db.projects).get();

  Future<void> _touch(int id, ProjectsCompanion c) =>
      (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(c.copyWith(updatedAt: Value(_now)));

  Future<void> setStatus(int id, String status) => _touch(id, ProjectsCompanion(status: Value(status)));

  Future<void> setEstimate(int id, {required int? costMinor, required String? currency}) =>
      _touch(id, ProjectsCompanion(estCostMinor: Value(costMinor), currencyCode: Value(currency)));

  Future<void> setTitle(int id, String title, String? description) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title');
    return _touch(id, ProjectsCompanion(title: Value(t), description: Value(description)));
  }

  /// Deletes the project with its steps and chat; tasks made from its steps stay as plain tasks.
  Future<void> delete(int id) => _db.transaction(() async {
    await (_db.update(_db.tasks)..where((t) => t.projectId.equals(id))).write(
      const TasksCompanion(projectId: Value(null), projectStepId: Value(null)),
    );
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  });

  // ---- steps

  Stream<List<ProjectStep>> watchSteps(int projectId) =>
      (_db.select(_db.projectSteps)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
          .watch();

  Future<List<ProjectStep>> stepsOf(int projectId) =>
      (_db.select(_db.projectSteps)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
          .get();

  /// The owner said OK to [plan]: it replaces the steps (done marks of steps with the same title are kept),
  /// sets the estimate when it has one, and moves an idea to planning.
  Future<void> applyPlan(int projectId, PlanProposal plan) => _db.transaction(() async {
    final old = await stepsOf(projectId);
    final doneTitles = {for (final s in old.where((s) => s.done)) s.title};
    await (_db.delete(_db.projectSteps)..where((s) => s.projectId.equals(projectId))).go();
    var seq = 1;
    for (final phase in plan.phases) {
      for (final step in phase.steps) {
        await _db
            .into(_db.projectSteps)
            .insert(
              ProjectStepsCompanion.insert(
                projectId: projectId,
                seq: seq++,
                phase: Value(phase.name),
                title: step.title,
                dueDate: Value(step.due),
                done: Value(doneTitles.contains(step.title)),
              ),
            );
      }
    }
    final project = await get(projectId);
    await _touch(
      projectId,
      ProjectsCompanion(
        status: Value(project?.status == 'idea' ? 'planning' : project?.status ?? 'planning'),
        estCostMinor: plan.estCostMinor == null ? const Value.absent() : Value(plan.estCostMinor),
        currencyCode: plan.estCostMinor == null ? const Value.absent() : Value(plan.currency),
      ),
    );
  });

  /// The planner says these steps are finished (by their number in the list).
  Future<void> applyStepUpdates(int projectId, List<StepUpdate> updates) async {
    for (final u in updates) {
      await (_db.update(_db.projectSteps)..where((s) => s.projectId.equals(projectId) & s.seq.equals(u.seq))).write(
        ProjectStepsCompanion(done: Value(u.done)),
      );
    }
    await _touch(projectId, const ProjectsCompanion());
  }

  Future<void> setStepDone(int stepId, bool done) =>
      (_db.update(_db.projectSteps)..where((s) => s.id.equals(stepId))).write(ProjectStepsCompanion(done: Value(done)));

  Future<void> linkTask(int stepId, int taskId) => (_db.update(
    _db.projectSteps,
  )..where((s) => s.id.equals(stepId))).write(ProjectStepsCompanion(taskId: Value(taskId)));

  // ---- chat

  Future<int> addMessage(int projectId, String role, String body) => _db
      .into(_db.projectMessages)
      .insert(ProjectMessagesCompanion.insert(projectId: projectId, role: role, body: body, createdAt: _now));

  Stream<List<ProjectMessage>> watchMessages(int projectId) =>
      (_db.select(_db.projectMessages)
            ..where((m) => m.projectId.equals(projectId))
            ..orderBy([(m) => OrderingTerm.asc(m.id)]))
          .watch();

  Future<List<ProjectMessage>> messagesOf(int projectId) =>
      (_db.select(_db.projectMessages)
            ..where((m) => m.projectId.equals(projectId))
            ..orderBy([(m) => OrderingTerm.asc(m.id)]))
          .get();
}
