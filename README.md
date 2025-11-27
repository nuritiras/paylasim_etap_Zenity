## Pardus ETAP 23 (Cinnamon) ve Pardus 23.4 GNOME’da çalışan, Zenity ile pencereli kurulum sihirbazı + menüde ikonu olan uygulama şeklinde bir çözüm var.

## Uygulamanın yapacağı şeyler:

### Windows paylaşımları için → IP, paylaşım adı, kullanıcı adı, şifre, domain alır

### /etc/samba/creds-... dosyasını oluşturur

### /etc/fstab içine otomatik satırı ekler

### /mnt/ogretmen gibi mount noktasını oluşturur, mount -a ile bağlar

### Tüm kullanıcılar için çalışan /usr/local/bin/ogretmen-kisayol.sh betiğini yazar

### Hem GNOME hem Cinnamon için autostart kaydı açar

### Menüye “Öğretmen Paylaşımı Kurucu” diye bir uygulama ekler (ikonlu)

### 🔒 Not: Bu uygulama sistem dosyalarına yazdığı için yönetici yetkisiyle (root) çalışmalı. Bunu pkexec ile çözüyoruz.

## 1. Gerekli paketler

## Önce Zenity ve CIFS araçları yüklü olsun:

### sudo apt install zenity cifs-utils gvfs-backends gvfs-fuse
## İzin er
### sudo chmod +x /usr/local/sbin/ogretmen-paylasim-kurucu.sh
## Çalıştır
### sudo ./ogretmen-paylasim-kurucu.sh 
