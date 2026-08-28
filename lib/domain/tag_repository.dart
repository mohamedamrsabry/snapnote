import 'tag.dart';

abstract class TagRepository {
  Future<List<Tag>> getTags();

  Future<void> saveTag(Tag tag);
}
