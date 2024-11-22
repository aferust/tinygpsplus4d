/*
TinyGPS++ - a small GPS library for Arduino providing universal NMEA parsing
Based on work by and "distanceBetween" and "courseTo" courtesy of Maarten Lamers.
Suggestion to add satellites, courseTo(), and cardinal() by Matt Monson.
Location precision improvements suggested by Wayne Holder.
Copyright (C) 2008-2024 Mikal Hart
All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

/+
    // This is a D port of the original C++ library licensed under LGPL 2.1+
    // Original Author: Mikal Hart
    // Original Source: https://github.com/mikalhart/TinyGPSPlus

    ported by Ferhat Kurtulmuş
+/

module tinygpsplus;

import std.stdint;

import core.stdc.inttypes;
import core.stdc.string;

enum TWO_PI = 2*PI;

enum _GPS_VERSION = "1.1.0"; // software version of this library (the original c++ code)
enum _GPS_MPH_PER_KNOT = 1.15077945;
enum _GPS_MPS_PER_KNOT = 0.51444444;
enum _GPS_KMPH_PER_KNOT = 1.852;
enum _GPS_MILES_PER_METER = 0.00062137112;
enum _GPS_KM_PER_METER = 0.001;
enum _GPS_FEET_PER_METER = 3.2808399;
enum _GPS_MAX_FIELD_SIZE = 15;
enum _GPS_EARTH_MEAN_RADIUS = 6371009;

enum _RMCterm = "RMC";
enum _GGAterm = "GGA";

auto COMBINE(uint sentenceType, uint termNumber) @nogc nothrow
{
    return (sentenceType << 5) | termNumber;
}

version( D_BetterC ){
    import core.stdc.ctype : isDigit = isdigit;
    import core.stdc.math;
    enum PI = 3.14159265358979323846;
}else{
    import std.ascii : isDigit;
    import std.math;
}

uint millis() @nogc nothrow
{
    import core.stdc.time;

    clock_t begin = clock();
    clock_t end = clock();
    double time_spent = cast(double)(end - begin) / CLOCKS_PER_SEC;

    return cast(uint)(time_spent * 1000);
}

struct RawDegrees
{
   uint16_t deg = 0;
   uint32_t billionths = 0;
   bool negative = false;
}

struct TinyGPSLocation
{
@nogc nothrow:
public:
    enum Quality { Invalid = '0', GPS = '1', DGPS = '2', PPS = '3', RTK = '4', FloatRTK = '5', Estimated = '6', Manual = '7', Simulated = '8' };
    enum Mode { N = 'N', A = 'A', D = 'D', E = 'E'};

    bool isValid() const    { return valid; }
    bool isUpdated() const  { return updated; }
    uint32_t age() const    { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }
    ref RawDegrees  rawLat()     { updated = false; return rawLatData; }
    ref RawDegrees rawLng()     { updated = false; return rawLngData; }

    double lat()
    {
        updated = false;
        double ret = rawLatData.deg + rawLatData.billionths / 1000000000.0;
        return rawLatData.negative ? -ret : ret;
    }

    double lng()
    {
        updated = false;
           double ret = rawLngData.deg + rawLngData.billionths / 1000000000.0;
           return rawLngData.negative ? -ret : ret;
    }

    Quality FixQuality()           { updated = false; return fixQuality; }
    Mode FixMode()                 { updated = false; return fixMode; }

private:
    bool valid = false, updated = false;
    RawDegrees rawLatData, rawLngData, rawNewLatData, rawNewLngData;
    Quality fixQuality = Quality.Invalid, newFixQuality;
    Mode fixMode = Mode.N, newFixMode;
    uint32_t lastCommitTime;

    void commit()
    {
        rawLatData = rawNewLatData;
        rawLngData = rawNewLngData;
        fixQuality = newFixQuality;
        fixMode = newFixMode;
        lastCommitTime = millis();
        valid = updated = true;
    }

    void setLatitude(char* term)
    {
        TinyGPSPlus.parseDegrees(term, rawNewLatData);
    }

    void setLongitude(char* term){
        TinyGPSPlus.parseDegrees(term, rawNewLngData);
    }
}

struct TinyGPSDate
{
@nogc nothrow:
public:
    bool isValid() const       { return valid; }
    bool isUpdated() const     { return updated; }
    uint32_t age() const       { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }

    uint32_t value()           { updated = false; return date; }
    
    uint16_t year()
    {
        updated = false;
        uint16_t year = date % 100;
        return cast(uint16_t)(year + 2000);
    }

    uint8_t month()
    {
        updated = false;
           return (date / 100) % 100;
    }

    uint8_t day()
    {
        updated = false;
           return cast(uint8_t)(date / 10000);
    }

private:
    bool valid = false, updated = false;
    uint32_t date = 0, newDate;
    uint32_t lastCommitTime;

    void commit()
    {
        date = newDate;
        lastCommitTime = millis();
        valid = updated = true;
    }

    void setDate(char* term)
    {
        newDate = cast(uint)atol(term);
    }
}

extern (C) long atol(const char *str) @nogc nothrow;

struct TinyGPSTime
{
@nogc nothrow:    
public:
    bool isValid() const       { return valid; }
    bool isUpdated() const     { return updated; }
    uint32_t age() const       { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }

    uint32_t value()           { updated = false; return time; }

    uint8_t hour()
    {
        updated = false;
           return cast(ubyte)(time / 1000000);
    }

    uint8_t minute()
    {
        updated = false;
           return (time / 10000) % 100;
    }

    uint8_t second()
    {
        updated = false;
           return (time / 100) % 100;
    }

    uint8_t centisecond()
    {
        updated = false;
           return time % 100;
    }

private:
    bool valid = false, updated = 0;
    uint32_t time = 0, newTime;
    uint32_t lastCommitTime;

    void commit()
    {
        time = newTime;
        lastCommitTime = millis();
        valid = updated = true;
    }

    void setTime(char* term)
    {
        newTime = cast(uint32_t)TinyGPSPlus.parseDecimal(term);
    }
}

mixin template TinyGPSDecimal()
{
@nogc nothrow:    
public:
    bool isValid() const    { return valid; }
    bool isUpdated() const  { return updated; }
    uint32_t age() const    { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }
    int32_t value()         { updated = false; return val; }

private:
    bool valid = false, updated = false;
    uint32_t lastCommitTime;
    int32_t val = 0, newval;

    void commit()
    {
        val = newval;
        lastCommitTime = millis();
        valid = updated = true;
    }

    void set(char* term)
    {
        newval = TinyGPSPlus.parseDecimal(term);
    }
}

struct TinyGPSInteger
{
@nogc nothrow:
public:
    bool isValid() const    { return valid; }
    bool isUpdated() const  { return updated; }
    uint32_t age() const    { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }
    uint32_t value()        { updated = false; return val; }

private:
    bool valid = false, updated = false;
    uint32_t lastCommitTime;
    uint32_t val = 0, newval;

    void commit()
    {
        val = newval;
        lastCommitTime = millis();
        valid = updated = true;
    }

    void set(char* term)
    {
        newval = cast(uint)atol(term);
    }
}

struct TinyGPSSpeed
{
    mixin TinyGPSDecimal;
    
    @nogc nothrow:
    double knots()    { return value() / 100.0; }
    double mph()      { return _GPS_MPH_PER_KNOT * value() / 100.0; }
    double mps()      { return _GPS_MPS_PER_KNOT * value() / 100.0; }
    double kmph()     { return _GPS_KMPH_PER_KNOT * value() / 100.0; }
}

struct TinyGPSCourse
{
    mixin TinyGPSDecimal;
    @nogc nothrow:
    double deg()      { return value() / 100.0; }
}

struct TinyGPSAltitude
{
    mixin TinyGPSDecimal;
    
    @nogc nothrow:
    double meters()       { return value() / 100.0; }
    double miles()        { return _GPS_MILES_PER_METER * value() / 100.0; }
    double kilometers()   { return _GPS_KM_PER_METER * value() / 100.0; }
    double feet()         { return _GPS_FEET_PER_METER * value() / 100.0; }
}

struct TinyGPSHDOP
{
    mixin TinyGPSDecimal;
    
    @nogc nothrow:
    double hdop() { return value() / 100.0; }
}

struct TinyGPSCustom
{
@nogc nothrow:
public:
    this(ref TinyGPSPlus gps, char* sentenceName, int termNumber)
    {
        begin(gps, sentenceName, termNumber);
    }
    
    void begin(ref TinyGPSPlus gps, char* _sentenceName, int _termNumber)
    {
        lastCommitTime = 0;
        updated = valid = false;
        sentenceName = _sentenceName;
        termNumber = _termNumber;
        stagingBuffer[] = '\0';
        buffer[] = '\0';
        // Insert this item into the GPS tree
        gps.insertCustom(&this, _sentenceName, _termNumber);
    }

    bool isUpdated() const  { return updated; }
    bool isValid() const    { return valid; }
    uint32_t age() const    { return valid ? millis() - lastCommitTime : cast(uint32_t)uint.max; }
    char* value()     { updated = false; return buffer.ptr; }

private:
    void commit()
    {
        this.buffer[] = this.stagingBuffer[];
        lastCommitTime = millis();
        valid = updated = true;
    }

    void set(const char *term)
    {
        stagingBuffer[0 .. stagingBuffer.length - 1] = term[0 .. stagingBuffer.length - 1];
    }

    char[_GPS_MAX_FIELD_SIZE + 1] stagingBuffer;
    char[_GPS_MAX_FIELD_SIZE + 1] buffer;
    uint lastCommitTime;
    bool valid, updated;
    char* sentenceName;
    int termNumber;
    TinyGPSCustom* next;
}

struct TinyGPSPlus
{
@nogc nothrow:
public:
      bool encode(char c) // process one character received from GPS
    {
        ++encodedCharCount;

        switch(c)
        {
        case ',': // term terminators
            parity ^= cast(uint8_t)c;
            goto case '\r';
        case '\r':
        case '\n':
        case '*':
            {
                bool isValidSentence = false;
                if (curTermOffset < term.sizeof)
                {
                    term[curTermOffset] = 0;
                    isValidSentence = endOfTermHandler();
                }
                ++curTermNumber;
                curTermOffset = 0;
                isChecksumTerm = c == '*';
                return isValidSentence;
            }
            break;

        case '$': // sentence begin
            curTermNumber = curTermOffset = 0;
            parity = 0;
            curSentenceType = GPS_SENTENCE_OTHER;
            isChecksumTerm = false;
            sentenceHasFix = false;
            return false;

        default: // ordinary characters
            if (curTermOffset < term.sizeof - 1)
            term[curTermOffset++] = c;
            if (!isChecksumTerm)
            parity ^= c;
            return false;
        }

        return false;
    }

    ref TinyGPSPlus opBinary(string op)(char c) @nogc nothrow{
        static if (op == "~"){
            encode(c); return *this;
        } 
        else static assert(0, "Operator "~op~" not implemented");
    }

    TinyGPSLocation location;
    TinyGPSDate date;
    TinyGPSTime time;
    TinyGPSSpeed speed;
    TinyGPSCourse course;
    TinyGPSAltitude altitude;
    TinyGPSInteger satellites;
    TinyGPSHDOP hdop;

    static string libraryVersion() { return _GPS_VERSION; }

    static double distanceBetween(double lat1, double long1, double lat2, double long2)
    {
        // returns distance in meters between two positions, both specified
        // as signed decimal-degrees latitude and longitude. Uses great-circle
        // distance computation for hypothetical sphere of radius 6371009 meters.
        // Because Earth is no exact sphere, rounding errors may be up to 0.5%.
        // Courtesy of Maarten Lamers
        double delta = radians(long1-long2);
        double sdlong = sin(delta);
        double cdlong = cos(delta);
        lat1 = radians(lat1);
        lat2 = radians(lat2);
        double slat1 = sin(lat1);
        double clat1 = cos(lat1);
        double slat2 = sin(lat2);
        double clat2 = cos(lat2);
        delta = (clat1 * slat2) - (slat1 * clat2 * cdlong);
        delta = delta*delta;
        auto term1 = clat2 * sdlong;
        delta += term1 * term1;
        delta = sqrt(delta);
        double denom = (slat1 * slat2) + (clat1 * clat2 * cdlong);
        delta = atan2(delta, denom);
        return delta * _GPS_EARTH_MEAN_RADIUS;
    }

    static double courseTo(double lat1, double long1, double lat2, double long2)
    {
        // returns course in degrees (North=0, West=270) from position 1 to position 2,
        // both specified as signed decimal-degrees latitude and longitude.
        // Because Earth is no exact sphere, calculated course may be off by a tiny fraction.
        // Courtesy of Maarten Lamers
        double dlon = radians(long2-long1);
        lat1 = radians(lat1);
        lat2 = radians(lat2);
        double a1 = sin(dlon) * cos(lat2);
        double a2 = sin(lat1) * cos(lat2) * cos(dlon);
        a2 = cos(lat1) * sin(lat2) - a2;
        a2 = atan2(a1, a2);
        if (a2 < 0.0)
        {
            a2 += TWO_PI;
        }
        return degrees(a2);
    }

    static immutable(char*) cardinal(double course)
    {
        static immutable(const(char)*[]) directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        int direction = cast(int)((course + 11.25f) / 22.5f);
        return directions[direction % 16];
    }

    static int32_t parseDecimal(char* term)
    {
        bool negative = *term == '-';
        if (negative) ++term;
        int32_t ret = 100 * cast(int32_t)atol(term);
        while (isDigit(*term)) ++term;
        if (*term == '.' && isDigit(term[1]))
        {
            ret += 10 * (term[1] - '0');
            if (isDigit(term[2]))
                ret += term[2] - '0';
        }
        return negative ? -ret : ret;
    }
    static void parseDegrees(char* term, ref RawDegrees deg)
    {
        uint32_t leftOfDecimal = cast(uint32_t)atol(term);
        uint16_t minutes = cast(uint16_t)(leftOfDecimal % 100);
        uint32_t multiplier = 10000000UL;
        uint32_t tenMillionthsOfMinutes = minutes * multiplier;

        deg.deg = cast(int16_t)(leftOfDecimal / 100);

        while (isDigit(*term))
            ++term;

        if (*term == '.')
            while (isDigit(*++term))
            {
                multiplier /= 10;
                tenMillionthsOfMinutes += (*term - '0') * multiplier;
            }

        deg.billionths = (5 * tenMillionthsOfMinutes + 1) / 3;
        deg.negative = false;
    }
    uint32_t charsProcessed()   const { return encodedCharCount; }
    uint32_t sentencesWithFix() const { return sentencesWithFixCount; }
    uint32_t failedChecksum()   const { return failedChecksumCount; }
    uint32_t passedChecksum()   const { return passedChecksumCount; }

private:
    enum {GPS_SENTENCE_GGA, GPS_SENTENCE_RMC, GPS_SENTENCE_OTHER}

    // parsing state variables
    uint8_t parity;
    bool isChecksumTerm;
    char[_GPS_MAX_FIELD_SIZE] term;
    uint8_t curSentenceType = GPS_SENTENCE_OTHER;
    uint8_t curTermNumber;
    uint8_t curTermOffset;
    bool sentenceHasFix;

    // custom element support
    TinyGPSCustom* customElts;
    TinyGPSCustom* customCandidates;

    void insertCustom(TinyGPSCustom* pElt, char* sentenceName, int termNumber)
    {
        TinyGPSCustom **ppelt;

        for (ppelt = &this.customElts; *ppelt != null; ppelt = &(*ppelt).next)
        {
            int cmp = strcmp(sentenceName, (*ppelt).sentenceName);
            if (cmp < 0 || (cmp == 0 && termNumber < (*ppelt).termNumber))
                break;
        }

        pElt.next = *ppelt;
        *ppelt = pElt;
    }

    // statistics
    uint32_t encodedCharCount;
    uint32_t sentencesWithFixCount;
    uint32_t failedChecksumCount;
    uint32_t passedChecksumCount;

    // internal utilities
    int fromHex(char a)
    {
        if (a >= 'A' && a <= 'F')
            return a - 'A' + 10;
        else if (a >= 'a' && a <= 'f')
            return a - 'a' + 10;
        else
            return a - '0';
    }

    bool endOfTermHandler()
    {
        // If it's the checksum term, and the checksum checks out, commit
        if (isChecksumTerm)
        {
            byte checksum = cast(byte)(16 * fromHex(term[0]) + fromHex(term[1]));
            if (checksum == parity)
            {
                passedChecksumCount++;
                if (sentenceHasFix)
                ++sentencesWithFixCount;

                switch(curSentenceType)
                {
                    case GPS_SENTENCE_RMC:
                        date.commit();
                        time.commit();
                        if (sentenceHasFix)
                        {
                            location.commit();
                            speed.commit();
                            course.commit();
                        }
                        break;
                    case GPS_SENTENCE_GGA:
                        time.commit();
                        if (sentenceHasFix)
                        {
                            location.commit();
                            altitude.commit();
                        }
                        satellites.commit();
                        hdop.commit();
                        break;
                    default:
                        break;
                }

                // Commit all custom listeners of this sentence type
                for (TinyGPSCustom *p = customCandidates; p != null && strcmp(p.sentenceName, customCandidates.sentenceName) == 0; p = p.next)
                    p.commit();
                return true;
            }

            else
            {
                ++failedChecksumCount;
            }

            return false;
        }

        // the first term determines the sentence type
        if (curTermNumber == 0)
        {
            if (term[0] == 'G' && strchr("PNABL", term[1]) != null && !strcmp(term.ptr + 2, _RMCterm))
                curSentenceType = GPS_SENTENCE_RMC;
            else if (term[0] == 'G' && strchr("PNABL", term[1]) != null && !strcmp(term.ptr + 2, _GGAterm))
                curSentenceType = GPS_SENTENCE_GGA;
            else
                curSentenceType = GPS_SENTENCE_OTHER;

            // Any custom candidates of this sentence type?
            for (customCandidates = customElts; customCandidates != null && strcmp(customCandidates.sentenceName, term.ptr) < 0; customCandidates = customCandidates.next){};
            if (customCandidates != null && strcmp(customCandidates.sentenceName, term.ptr) > 0)
                customCandidates = null;

            return false;
        }

        if (curSentenceType != GPS_SENTENCE_OTHER && term[0])
        switch(COMBINE(curSentenceType, curTermNumber))
        {
        case COMBINE(GPS_SENTENCE_RMC, 1): // Time in both sentences
        case COMBINE(GPS_SENTENCE_GGA, 1):
            time.setTime(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 2): // RMC validity
            sentenceHasFix = term[0] == 'A';
            break;
        case COMBINE(GPS_SENTENCE_RMC, 3): // Latitude
        case COMBINE(GPS_SENTENCE_GGA, 2):
            location.setLatitude(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 4): // N/S
        case COMBINE(GPS_SENTENCE_GGA, 3):
            location.rawNewLatData.negative = term[0] == 'S';
            break;
        case COMBINE(GPS_SENTENCE_RMC, 5): // Longitude
        case COMBINE(GPS_SENTENCE_GGA, 4):
            location.setLongitude(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 6): // E/W
        case COMBINE(GPS_SENTENCE_GGA, 5):
            location.rawNewLngData.negative = term[0] == 'W';
            break;
        case COMBINE(GPS_SENTENCE_RMC, 7): // Speed (RMC)
            speed.set(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 8): // Course (RMC)
            course.set(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 9): // Date (RMC)
            date.setDate(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_GGA, 6): // Fix data (GGA)
            sentenceHasFix = term[0] > '0';
            location.newFixQuality = cast(TinyGPSLocation.Quality)term[0];
            break;
        case COMBINE(GPS_SENTENCE_GGA, 7): // Satellites used (GGA)
            satellites.set(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_GGA, 8): // HDOP
            hdop.set(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_GGA, 9): // Altitude (GGA)
            altitude.set(term.ptr);
            break;
        case COMBINE(GPS_SENTENCE_RMC, 12):
            location.newFixMode = cast(TinyGPSLocation.Mode)term[0];
            break;
        default:
            break;
        }

        // Set custom values as needed
        for (TinyGPSCustom *p = customCandidates; p != null && strcmp(p.sentenceName, customCandidates.sentenceName) == 0 && p.termNumber <= curTermNumber; p = p.next)
        if (p.termNumber == curTermNumber)
                p.set(term.ptr);

        return false;
    }
}

double radians(double degrees) @nogc nothrow
{
    return degrees * (PI / 180.0);
}

double degrees(double radians) @nogc nothrow
{
    return radians * (180.0 / PI);
}