# zmykamy.pl

- aplikacja mobilna do planowania wspólnych wyjazdów
- wszystko w jednym miejscu: plan, wydatki, uczestnicy i galeria

## Funkcjonalności

- każdy ma konto, więc logowanie/rejestracja
- lista uczestników, dodawanie użytkowników do wyjazdu
- ekran dla inspiracji wyjazdowych: animowany globus, którym można kręcić, żeby wybrać cel podróży
- plan wyjazdu: można rozpisać dzień po dniu z godzinami, lub ogólne informacje o wyjeździe i notować rzeczy, które będą potrzebne do zrobienia przed wyjazdem (np. kupić bilet, zrobić rezerwację, spakować się)
  - przed wyjazdem jest checklista rzeczy do zrobienia/spakowania oraz odliczenie do wyjazdu w dniach
  - na podstawie planowanych miejsc automatycznie pokazuje się pogoda w danym miejscu każdego dnia w trakcie wyjazdu, oraz link do nawigacji (Google Maps, Apple Maps, Waze itp.) do miejsc docelowych - wyróżniamy te opcje w godzinach planowanej podróży w dane miejsce
- możliwość dodawania notatek i dokumentów do wyjazdu, żeby każdy miał łatwy dostęp w trakcie: np. bilety, rezerwacje, kody do mieszkania, itp.; możliwość "przypięcia" ważnych notatek, żeby zawsze były widoczne dla każdego na górze ekranu wyjazdu
- narzędzia wyjazdowe: np. kalkulator walut, przelicznik jednostek, głosowanie na atrakcje lub lokale restauracyjne
- dodawanie wydatków: kto zapłacił za kogo, wybór jednej "bazowej" waluty wyjazdu, pierowtnie obsługiwane są tylko wydatki w bazowej walucie; na koniec wyjazdu podsumowanie, kto komu ile jest winien - rozliczenie salda za pomocą ukierunkowanego grafu należności
  - rozbudowa walutowa do wydatków: dodanie wyboru waluty konkretnego wydatku z automatycznym przeliczeniem tego na walutę bazową wyjazdu (np. kalkulator/przelicznik NBP lub wpisanie ręcznie wartości z informacyjnym kursem wymiany)
- wspólna galeria zdjęć i filmów z wyjazdu (z potencjalną możliwością linkowania zewnętrznego serwisu, np. Google Photos)

## Ekrany w apce

1. logowanie/rejestracja
2. lista wyjazdów
3. tworzenie wyjazdu

   1. generator inspiracji wyjazdowych (globus)
   2. kreator planu wyjazdu

4. szczegóły danego wyjazdu

   1. plan wyjazdu - przed wyjazdem jest też checklista pakowania i odlicznie
   2. narzędzia wyjazdowe
   3. dokumenty wyjazdowe
   4. wydatki wyjazdu
   5. uczestnicy i zaproszenia
   6. galeria zdjęć i filmów
   7. podsumowanie i rozliczenie wydatków
