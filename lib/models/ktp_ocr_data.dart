class KtpOcrData {
  final String? ocrSessionId;
  final String? nik;
  final String? nama;
  final String? tempatLahir;
  final String? tanggalLahir;
  final String? jenisKelamin;
  final String? alamat;
  final String? agama;
  final String? statusPerkawinan;
  final String? pekerjaan;
  final String? kewarganegaraan;

  const KtpOcrData({
    this.ocrSessionId,
    this.nik,
    this.nama,
    this.tempatLahir,
    this.tanggalLahir,
    this.jenisKelamin,
    this.alamat,
    this.agama,
    this.statusPerkawinan,
    this.pekerjaan,
    this.kewarganegaraan,
  });

  factory KtpOcrData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    return KtpOcrData(
      ocrSessionId:
          (data['ocrSessionId'] ??
                  data['ocr_session_id'] ??
                  json['ocrSessionId'] ??
                  json['ocr_session_id'])
              ?.toString(),
      nik: data['nik']?.toString(),
      nama: data['nama']?.toString(),
      tempatLahir: (data['tempat_lahir'] ?? data['tempatLahir'])?.toString(),
      tanggalLahir: (data['tanggal_lahir'] ?? data['tanggalLahir'])?.toString(),
      jenisKelamin: (data['jenis_kelamin'] ?? data['jenisKelamin'])?.toString(),
      alamat: data['alamat']?.toString(),
      agama: data['agama']?.toString(),
      statusPerkawinan: (data['status_perkawinan'] ?? data['statusPerkawinan'])
          ?.toString(),
      pekerjaan: data['pekerjaan']?.toString(),
      kewarganegaraan: data['kewarganegaraan']?.toString(),
    );
  }
}
