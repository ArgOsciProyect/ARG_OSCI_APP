// lib/features/data_acquisition/domain/repository/data_acquisition_repository.dart

abstract class DataAcquisitionRepository {
  Future<void> fetchData();
}