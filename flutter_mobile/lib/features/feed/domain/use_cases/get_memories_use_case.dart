import 'package:flutter_mobile/core/models/memory.dart';
import '../i_memory_repository.dart';

class GetMemoriesUseCase {
  final IMemoryRepository _repository;

  const GetMemoriesUseCase(this._repository);

  Future<List<KiokuMemory>> call(String albumId) {
    return _repository.getMemories(albumId);
  }
}
