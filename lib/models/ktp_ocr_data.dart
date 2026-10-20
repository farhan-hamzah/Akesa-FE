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
    return KtpOcrData(
      ocrSessionId: (json['ocrSessionId'] ?? json['ocr_session_id'])
          ?.toString(),
      nik: json['nik']?.toString(),
      nama: json['nama']?.toString(),
      tempatLahir: json['tempat_lahir']?.toString(),
      tanggalLahir: json['tanggal_lahir']?.toString(),
      jenisKelamin: json['jenis_kelamin']?.toString(),
      alamat: json['alamat']?.toString(),
      agama: json['agama']?.toString(),
      statusPerkawinan: json['status_perkawinan']?.toString(),
      pekerjaan: json['pekerjaan']?.toString(),
      kewarganegaraan: json['kewarganegaraan']?.toString(),
    );
  }
}
