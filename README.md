# Invition

Flutter web nikoh taklifnomasi. Dizayn screen recordingdagi minimal "wenday"
ko'rinishga moslangan: katta serif ismlar, oq fon, yumshoq kartalar, countdown,
manzil tugmalari va Firebase Firestore orqali tilaklar.

## Ma'lumotlarni almashtirish

Asosiy matnlar `lib/main.dart` faylidagi `InvitationContent` classida turadi:

- `groom`, `bride`
- `dateText`, `weekDay`, `dayAndMonth`, `timeText`, `weddingDate`
- `venueName`, `venueAddress`
- `googleMap`, `yandexMap`

## Lokal ishga tushirish

```bash
flutter pub get
flutter run -d chrome
```

Statik build:

```bash
flutter build web
```

## Firebase

Tilaklar `wedding_responses` collectioniga yoziladi. Hozirgi hujjat format:

- `name`
- `message`
- `createdAt`

Firestore qoidalari `firestore.rules` faylida.

```bash
firebase deploy --only firestore:rules
flutter build web
firebase deploy --only hosting
```
