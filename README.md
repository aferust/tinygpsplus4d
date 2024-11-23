# TinyGPSPlus4d

 * A dlang port of the [TinyGPSPlus](https://github.com/mikalhart/TinyGPSPlus).
 * Compatible with betterC.
 * It never uses dynamic allocations.
 * It allows you parsing NMEA sentences read from [GPS receivers](https://randomnerdtutorials.com/esp32-neo-6m-gps-module-arduino/).

## Example:
```d
import tinygpsplus;

TinyGPSPlus gps;

extern (C) int main()
{
    string gpsStream =
"$GPRMC,045103.000,A,3014.1984,N,09749.2872,W,0.67,161.46,030913,,,A*7C\r\n
$GPGGA,045104.000,3014.1985,N,09749.2873,W,1,09,1.2,211.6,M,-22.5,M,,0000*62\r\n
$GPRMC,045200.000,A,3014.3820,N,09748.9514,W,36.88,65.02,030913,,,A*77\r\n
$GPGGA,045201.000,3014.3864,N,09748.9411,W,1,10,1.2,200.8,M,-22.5,M,,0000*6C\r\n
$GPRMC,045251.000,A,3014.4275,N,09749.0626,W,0.51,217.94,030913,,,A*7D\r\n
$GPGGA,045252.000,3014.4273,N,09749.0628,W,1,09,1.3,206.9,M,-22.5,M,,0000*6F\r\n";
    

    foreach (char c; gpsStream)
    {
        if (gps.encode(c))
                displayInfo();
    }

    return 0;
}

void displayInfo()
{
    import core.stdc.stdio;

    printf("Location: "); 
    if (gps.location.isValid())
    {
        printf("%.6f,%.6f", gps.location.lat(), gps.location.lng());
    }
    else
    {
        printf("INVALID");
    }

    printf("  Date/Time: ");
    if (gps.date.isValid())
    {
        printf("%d/%d/%d",
            gps.date.day(),
            gps.date.month(),
            gps.date.year()
        );
    }
    else
    {
        printf("INVALID");
    }

    printf(" ");
    if (gps.time.isValid())
    {
        if (gps.time.hour() < 10) printf("0");
        printf("%d", gps.time.hour());
        printf(":");
        if (gps.time.minute() < 10) printf("0");
        printf("%d", gps.time.minute());
        printf(":");
        if (gps.time.second() < 10) printf("0");
        printf("%d", gps.time.second());
        printf(".");
        if (gps.time.centisecond() < 10) printf("0");
        printf("%d", gps.time.centisecond());
    }
    else
    {
        printf("INVALID");
    }

    printf(" HDOP: %.1f", gps.hdop.hdop());
    printf(" Nof.sat: %d", gps.satellites.value());
    printf("\n");
}
```