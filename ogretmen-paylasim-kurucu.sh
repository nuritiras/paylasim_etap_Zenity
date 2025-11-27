#!/bin/bash

# Root kontrolü
if [ "$EUID" -ne 0 ]; then
    zenity --error --title="Yetki Hatası" --text="Bu uygulamayı yönetici olarak (root) çalıştırmalısınız.\n\nÖrnek:\n\nsudo /usr/local/sbin/ogretmen-paylasim-kurucu.sh"
    exit 1
fi

if ! command -v zenity >/dev/null 2>&1; then
    echo "Zenity yüklü değil. Önce: sudo apt install zenity"
    exit 1
fi

# 1) Sunucu IP/Adı
SERVER_IP=$(zenity --entry \
    --title="Sunucu Bilgisi" \
    --text="Windows Server IP adresini veya adını girin:" \
    --entry-text="10.10.10.5") || exit 0

[ -z "$SERVER_IP" ] && zenity --error --text="Sunucu IP/adı boş olamaz." && exit 1

# 2) Paylaşım adı
SHARE_NAME=$(zenity --entry \
    --title="Paylaşım Adı" \
    --text="Windows üzerinde paylaşıma verilen klasör adı:" \
    --entry-text="ogretmen") || exit 0

[ -z "$SHARE_NAME" ] && zenity --error --text="Paylaşım adı boş olamaz." && exit 1

# 3) Mount noktası
DEFAULT_MOUNT="/mnt/$SHARE_NAME"
MOUNT_POINT=$(zenity --entry \
    --title="Bağlantı (Mount) Noktası" \
    --text="Paylaşımın bağlanacağı yerel klasör:" \
    --entry-text="$DEFAULT_MOUNT") || exit 0

[ -z "$MOUNT_POINT" ] && zenity --error --text="Mount noktası boş olamaz." && exit 1

# 4) Windows kullanıcı adı
WIN_USER=$(zenity --entry \
    --title="Windows Kullanıcı Adı" \
    --text="Windows Server üzerinde yetkili kullanıcı adı:" \
    --entry-text="ogrt") || exit 0

[ -z "$WIN_USER" ] && zenity --error --text="Kullanıcı adı boş olamaz." && exit 1

# 5) Windows şifre
WIN_PASS=$(zenity --password \
    --title="Windows Şifre" \
    --text="Windows kullanıcısının şifresini girin:") || exit 0

[ -z "$WIN_PASS" ] && zenity --error --text="Şifre boş olamaz." && exit 1

# 6) Domain / Workgroup
WIN_DOMAIN=$(zenity --entry \
    --title="Domain / Workgroup" \
    --text="Windows domain veya workgroup adı (bilmiyorsanız WORKGROUP bırakın):" \
    --entry-text="WORKGROUP") || exit 0

[ -z "$WIN_DOMAIN" ] && WIN_DOMAIN="WORKGROUP"

# Özet ekranı
zenity --question --title="Onay" --width=400 --text="Aşağıdaki ayarlar uygulanacak:\n
Sunucu:  $SERVER_IP
Paylaşım: $SHARE_NAME
Mount noktası: $MOUNT_POINT
Windows kullanıcı: $WIN_USER
Domain/Workgroup: $WIN_DOMAIN

Devam etmek istiyor musunuz?" || exit 0

# 1) Mount klasörünü oluştur
mkdir -p "$MOUNT_POINT"

# 2) Kimlik bilgisi dosyası
CRED_FILE="/etc/samba/creds-$SHARE_NAME"

cat <<EOF > "$CRED_FILE"
username=$WIN_USER
password=$WIN_PASS
domain=$WIN_DOMAIN
EOF

chmod 600 "$CRED_FILE"

# 3) /etc/fstab ayarı
FSTAB_BACKUP="/etc/fstab.$(date +%Y%m%d-%H%M%S).bak"
cp /etc/fstab "$FSTAB_BACKUP"

# Eski blok varsa temizle
sed -i '/# OGRETMEN_PAYLASIM_BASLA/,/# OGRETMEN_PAYLASIM_BITIR/d' /etc/fstab

cat <<EOF >> /etc/fstab

# OGRETMEN_PAYLASIM_BASLA
//$SERVER_IP/$SHARE_NAME  $MOUNT_POINT  cifs  credentials=$CRED_FILE,iocharset=utf8,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,nofail  0  0
# OGRETMEN_PAYLASIM_BITIR
EOF

# 4) Mount denemesi
if ! mount -a 2>/tmp/ogretmen-mount-hata.log; then
    HATA=$(cat /tmp/ogretmen-mount-hata.log)
    zenity --error --width=500 --title="Mount Hatası" --text="mount -a komutu başarısız oldu.\n\nYedek fstab: $FSTAB_BACKUP\n\nHata:\n$HATA"
    exit 1
fi

# 5) Tüm kullanıcılar için kısayol scripti
KISAYOL_SCRIPT="/usr/local/bin/ogretmen-kisayol.sh"

cat <<'EOF' > "$KISAYOL_SCRIPT"
#!/bin/bash

# Bu satır, ana kurucu tarafından doldurulacak
MOUNT_DIR="__MOUNT_DIR__"

# Kullanıcının masaüstü klasörünü bul
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null)"

if [ -z "$DESKTOP_DIR" ]; then
    if [ -d "$HOME/Masaüstü" ]; then
        DESKTOP_DIR="$HOME/Masaüstü"
    elif [ -d "$HOME/Desktop" ]; then
        DESKTOP_DIR="$HOME/Desktop"
    else
        DESKTOP_DIR="$HOME/Masaüstü"
        mkdir -p "$DESKTOP_DIR"
    fi
fi

mkdir -p "$DESKTOP_DIR"

SHORTCUT="$DESKTOP_DIR/ogretmen-paylasim.desktop"

cat <<EOD > "$SHORTCUT"
[Desktop Entry]
Type=Application
Name=Öğretmen Paylaşımı
Icon=folder-remote
Exec=xdg-open "$MOUNT_DIR"
Terminal=false
EOD

chmod +x "$SHORTCUT"
EOF

# Script içinde mount noktasını gerçek değerle değiştir
sed -i "s|__MOUNT_DIR__|$MOUNT_POINT|g" "$KISAYOL_SCRIPT"
chmod +x "$KISAYOL_SCRIPT"

# 6) Autostart kaydı (GNOME + Cinnamon)
AUTOSTART_FILE="/etc/xdg/autostart/ogretmen-kisayol.desktop"

cat <<EOF > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Name=Öğretmen Paylaşımı Kısayol Oluşturucu
Exec=/usr/local/bin/ogretmen-kisayol.sh
OnlyShowIn=GNOME;X-Cinnamon;
NoDisplay=true
EOF

chmod 644 "$AUTOSTART_FILE"

# 7) Başarılı mesajı
zenity --info --width=400 --title="İşlem Tamamlandı" --text="Öğretmen paylaşımı ayarları başarıyla uygulandı.\n\n• Paylaşım: //$SERVER_IP/$SHARE_NAME\n• Mount noktası: $MOUNT_POINT\n• Kısayol: Kullanıcılar giriş yaptıklarında kendi masaüstlerinde oluşturulacak.\n\nDeğişiklik etkin olsun diye kullanıcıların oturumu kapatıp yeniden açmaları önerilir."
exit 0

