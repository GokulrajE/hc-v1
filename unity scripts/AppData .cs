using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Threading;
using System.Runtime;
using System.IO;
using System;
// using System.String;
using System.Diagnostics;
using Debug = UnityEngine.Debug;
using System.Text.RegularExpressions;
using System.ComponentModel;
using System.Data;

using System.Drawing;
using Random = UnityEngine.Random;
using System.Globalization;


static class JediDataFormat
{
   
    static public string dformat { get; private set; }
    static public char[] dataTypes { get; private set; }
    static public int dataSize = -1;
    static public string[] dataLabels { get; private set; }
    static public readonly char[] FormatChars = new char[] { 'b', 'i', 'f' };
    static public readonly int[] FormatCharSize = new int[] { 1, 2, 4 };

    static public void ReadSetJediDataFormat(string filename)
    {
        dformat = "";
        // Open the file to read from.
        string[] allformatlines = File.ReadAllLines(filename);
        List<char> _dtypes = new List<char>();
        List<string> _dlabels = new List<string>();
        dataSize = 0;
        foreach (string line in allformatlines)
        {
            if (line.Length > 0)
            {
                // Split line by spaces
                string[] linecomps = line.Split(new char[] { ' ', }, StringSplitOptions.RemoveEmptyEntries);
                if (linecomps[0].Length == 1 && Array.Exists(JediDataFormat.FormatChars, chr => chr == linecomps[0][0]))
                {
                    dformat += linecomps[0];
                    _dtypes.Add(linecomps[0][0]);
                    _dlabels.Add(String.Join(" ", linecomps).Substring(2));
                    dataSize += FormatCharSize[Array.IndexOf(FormatChars, linecomps[0][0])];
                }
                else
                {
                    dformat = null;
                    dataTypes = null;
                    dataLabels = null;
                    dataSize = -1;
                    return;
                }
            }
        }
        dataTypes = _dtypes.ToArray();
        dataLabels = _dlabels.ToArray();
        
    }
    
    static public bool IsValidFormatLine(string line)
    {
        
        return false;
    }

    static public float GetFloatValue(int datainx, object dataval)
    {
        
        switch (dataTypes[datainx])
        {
            case 'b':
                return (float)((byte)dataval);
            case 'i':
                return (float)((UInt16)dataval);
            default:
                return (float)dataval;
        }
    }
}


public class ROM
{
    // Class attributes to store data read from the file
    public string datetime;
    public string side;
    
    public string mechanism{ get; private set; }
    //handle
    public float handleMin;
    public float handleMax;
    public float gripForce;

    //gross knob
    public float grossKnobMin;
    public float grossKnobMax;

    //fine knob
    public float fineKnobMin;
    public float fineKnobMax;

    //key Knob
    public float keyKnobMin;
    public float keyKnobMax;

    //Tripod Grasp
    public float tripodMin;
    public float tripodMax;
    public bool isAromSet { get => aromMin != 0 || aromMax != 0; }
    public bool isSet { get => isAromSet;}
    // public string mechanism;
    public float aromMin, aromMax;
     public static string[] FILEHEADER = new string[] {
        "DateTime", "AromMin", "AromMax"
    };
     public static string[] HFILEHEADER = new string[] {
        "DateTime", "AromMin", "AromMax","GripForce"
    };

    public string filePath = AppData.idPath;
     public void SetMechanism(string mech) => mechanism = (mechanism == null) ? mech : mechanism;


    // Constructor that reads the file and initializes values based on the mechanism
    public ROM(string mech)
    {
        string lastLine = "";
        mechanism = mech;
        string[] values;
        string fileName = $"{DataManager.romPath}/{mechanism}-rom.csv";
        // Create the file if it doesn't exist
        if (!File.Exists(fileName))
        {
            using (var writer = new StreamWriter(fileName, false, Encoding.UTF8))
            {
                if (AppData.selectedMechanism == JediSerialPayload.MECHANISMS[1])
                {
                    writer.WriteLine(string.Join(",", HFILEHEADER));
                }
                else writer.WriteLine(string.Join(",", FILEHEADER));
            }
        }


        try
        {
            using (StreamReader file = new StreamReader(fileName))
            {
                while (!file.EndOfStream)
                {
                    lastLine = file.ReadLine();
                }
            }
            values = lastLine.Split(',');
            if (mech != "HGF")
            {
                if (values[0].Trim() != null)
                {
                    // Assign values if mechanism matches
                    datetime = values[0].Trim();
                    aromMin = float.Parse(values[1].Trim());
                    aromMax = float.Parse(values[2].Trim());
                    Debug.Log($"while reading :{aromMin}, {aromMax}");
                }
                else
                {
                    // Handle case when no matching mechanism is found
                    datetime = null;
                    aromMin = 0;
                    aromMax = 0;
                }
            }
            else
            {
                if (values[0].Trim() != null)
                {
                    // Assign values if mechanism matches
                    datetime = values[0].Trim();
                    aromMin = float.Parse(values[1].Trim());
                    aromMax = float.Parse(values[2].Trim());
                    gripForce = float.Parse(values[3].Trim());

                }
                else
                {
                    // Handle case when no matching mechanism is found
                    datetime = null;
                    aromMin = 0;
                    aromMax = 0;
                    gripForce = 0;
                }
            }

        }
        catch (Exception ex)
        {
            Console.WriteLine("Error reading the file: " + ex.Message);
        }
    }

    public ROM()
    {
        aromMin = 0;
        aromMax = 0;
        gripForce = 0;
        mechanism = null;
        datetime = null;
    }

    public ROM(float hMin, float hMax, float gForce, float gMin, float gMax, float fMin, float fMax, float kMin, float kMax, float tMin, float tMax, bool tofile)
    {
        // handleMin = hMin;
        // handleMax = hMax;
        // gripForce = gForce;
        // grossKnobMin = gMin;
        // grossKnobMax = gMax;
        // fineKnobMin = fMin;
        // fineKnobMax = fMax;
        // keyKnobMin = kMin;
        // keyKnobMax = kMax;
        // tripodMin = tMin;
        // tripodMax = tMax;
        // datetime = DateTime.Now.ToString();

        // if (tofile)
        // {
        //     // Write data to assessment file.
        //     WriteToAssessmentFile();
        // }
    }
    public void SetArom(float min, float max)
    {
        aromMin = min;
        aromMax = max;
        datetime = DateTime.Now.ToString();
    }
    public void SetArom(float min, float max, float force)
    {
        aromMin = min;
        aromMax = max;
        gripForce = force;
        datetime = DateTime.Now.ToString();
    }

    public void WriteToAssessmentFile()
    {
                string _fname = $"{DataManager.romPath}/{AppData.selectedMechanism}-rom.csv";

        UnityEngine.Debug.Log(_fname);
        using (StreamWriter file = new StreamWriter(_fname, true))
        {
            if (AppData.selectedMechanism == JediSerialPayload.MECHANISMS[1])
            {
                file.WriteLine(datetime + ", " + aromMin.ToString() + ", " + aromMax.ToString()+", "+ gripForce.ToString());   
            }
            else file.WriteLine(datetime + ", " + aromMin.ToString() + ", " + aromMax.ToString());
        }
        Debug.Log("Writing");

    }

    // private void ReadFromFile(string mechanismName)
    // {
    //     string fileName = DataManager.GetRomFileName(mechanismName);
    //     // Create the file if it doesn't exist
    //     if (!File.Exists(fileName))
    //     {
    //         using (var writer = new StreamWriter(fileName, false, Encoding.UTF8))
    //         {
    //             if (AppData.selectedMechanism == JediSerialPayload.MECHANISMS[1])
    //             {
    //                 writer.WriteLine(string.Join(",", HFILEHEADER));
    //             }
    //             else writer.WriteLine(string.Join(",", FILEHEADER));
    //         }
    //     }
    //     // Read file.
    //     DataTable romData = DataManager.loadCSV(fileName);
    //     // Check the number of rows.
    //     if (romData.Rows.Count == 0)
    //     {
    //         // Set default values for the mechanism.
    //         datetime = null;
    //         mechanism = mechanismName;
    //         aromMin = 0;
    //         aromMax = 0;
    //         gripForce = 0;
    //         return;
    //     }
    //     if (AppData.selectedMechanism == JediSerialPayload.MECHANISMS[1])
    //     {
    //         // Assign ROM from the last row.
    //         datetime = romData.Rows[romData.Rows.Count - 1].Field<string>("DateTime");
    //         mechanism = mechanismName;
    //         aromMin = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("AromMin"));
    //         aromMax = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("AromMax"));
    //         gripForce = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("GripForce"));
    //     }
    //     else
    //     {
    //                  // Assign ROM from the last row.
    //         datetime = romData.Rows[romData.Rows.Count - 1].Field<string>("DateTime");
    //         mechanism = mechanismName;
    //         aromMin = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("AromMin"));
    //         aromMax = float.Parse(romData.Rows[romData.Rows.Count - 1].Field<string>("AromMax"));   
    //     }
        
    // }


}


public static class gameData
{
    //Assessment check
    public static bool isPROMcompleted = false;
    public static bool isAROMcompleted = false;
    //AAN controller check
    public static bool isBallReached = false;
    public static bool targetSpwan = false;
    public static bool isAROMEnabled = false;
    //game
    public static bool isGameLogging;
    public static string game;
    public static int gameScore;
    public static int totalTargets = 0;
    public static int reps;
    public static int playerScore;
    public static int enemyScore;
    public static string playerPos = "0";
    public static string playerPosition = "0";
    public static string enemyPos = "0";
    public static string playerHit = "0";
    public static string enemyHit = "0";
    public static string wallBounce = "0";
    public static string enemyFail = "0";
    public static string playerFail = "0";
    public static int winningScore = 3;
    public static float moveTime;
    public static readonly string[] pongEvents = new string[] { "moving", "wallBounce", "playerHit", "enemyHit", "playerFail", "enemyFail" };
    public static readonly string[] hatEvents = new string[] { "moving", "BallCaught", "BombCaught", "BallMissed", "BombMissed" };
    public static readonly string[] tukEvents = new string[] { "moving", "collided", "passed" };
    public static readonly string[] pacManEvents = new string[] { "moving", "captured", "Dead" };
    public static readonly string[] spaceEvents = new string[] { "moving", "destroyed", "dead" };
    public static int events;
    public static string TargetPos;
    public static float successRate;
    public static float gameSpeedTT;
    public static float gameSpeedPP;
    public static float gameSpeedHT;
    public static float predictedHitY;
    public static bool setNeutral = false;
    private static DataLogger dataLog;
    private static readonly string[] gameHeader = new string[] {"playerPosY","enemyPosY","targetPosXY","events","playerScore","enemyScore"
    };
    private static readonly string[] tukTukHeader = new string[] {"playerPosx", "targetPos","events","playerScore"
    };
    private static readonly string[] pacManHeader = new string[] { "events", "playerScore" };
    public static readonly string[] spaceHeader = new string[] { "playerPosX", "events", "playerScore" };
    public static bool isLogging { get; private set; }
    public static bool moving = true; // used to manipulate events in HAT TRICK
    static public void StartDataLog(string fname)
    {
        if (dataLog != null)
        {
            StopLogging();
        }
        // Start new logger
        if (AppData.selectedGame == "pingPong")
        {
            if (fname != "")
            {
                string instructionLine = "0 - moving, 1 - wallBounce, 2 - playerHit, 3 - enemyHit, 4 - playerFail, 5 - enemyFail\n";
                string headerWithInstructions = instructionLine + String.Join(", ", gameHeader) + "\n";
                dataLog = new DataLogger(fname, headerWithInstructions);
                isLogging = true;
            }
            else
            {
                dataLog = null;
                isLogging = false;
            }
        }
        else if ((AppData.selectedGame == "autoRider")||(AppData.selectedGame == "highwayRacer"))
        {
            if (fname != "")
            {
                string instructionLine = "0 - moving, 1 - collided, 2 - passed\n";
                string headerWithInstructions = instructionLine + String.Join(", ", tukTukHeader) + "\n";
                dataLog = new DataLogger(fname, headerWithInstructions);
                isLogging = true;
            }
            else
            {
                dataLog = null;
                isLogging = false;
            }
        }
        else if (AppData.selectedGame == "spaceShooter")
        {
            if (fname != "")
            {
                string instructionLine = "0 - moving, 1 - enemyDestroyed, 2 - dead\n";
                string headerWithInstructions = instructionLine + String.Join(", ", spaceHeader) + "\n";
                dataLog = new DataLogger(fname, headerWithInstructions);
                isLogging = true;
            }
            else
            {
                dataLog = null;
                isLogging = false;
            }
        }
        else if ((AppData.selectedGame == "pacMan") || (AppData.selectedGame == "snakeGame"))
        {
            if (fname != "")
            {
                string instructionLine = "0 - moving, 1 - captured, 2 - Dead \n";
                string headerWithInstructions = instructionLine + String.Join(", ", pacManHeader) + "\n";
                dataLog = new DataLogger(fname, headerWithInstructions);
                isLogging = true;
            }
            else
            {
                dataLog = null;
                isLogging = false;
            }
        }
        else
        {
            Debug.Log("Unknown Game");
        }
    }
    static public void StopLogging()
    {
        if (dataLog != null)
        {
            UnityEngine.Debug.Log("Null log not");
            dataLog.stopDataLog(true);
            dataLog = null;
            isLogging = false;
        }
        else
            UnityEngine.Debug.Log("Null log");
    }

    static public void LogDataPP()
    {
        
            string[] _data = new string[] {
                playerPos,
                enemyPos,
                TargetPos,
                events.ToString("F2"),
                playerScore.ToString("F2"),
                enemyScore.ToString("F2")
            };
            string _dstring = String.Join(", ", _data);
            _dstring += "\n";
            dataLog.logData(_dstring);
        
    }

    static public void LogDataAR()
    {
        string[] _data = new string[] {
                playerPos,
                TargetPos,
                events.ToString("F2"),
                gameScore.ToString("F2")
            };
        string _dstring = String.Join(", ", _data);
        _dstring += "\n";
        dataLog.logData(_dstring);

    }
    static public void LogDataSS()
    {
        string[] _data = new string[] {
                playerPos,
                events.ToString("F2"),
                gameScore.ToString("F2")
            };
        string _dstring = String.Join(", ", _data);
        _dstring += "\n";
        dataLog.logData(_dstring);

    }
    static public void LogDataHR()
    {
            string[] _data = new string[] {
               playerPos,
               enemyPos,
               gameData.events.ToString("F2"),
               gameData.gameScore.ToString("F2")
            };
            string _dstring = String.Join(", ", _data);
            _dstring += "\n";
            dataLog.logData(_dstring);
        }

    static public void LogDataPM()
    {
        string[] _data = new string[] {
                events.ToString("F2"),
                gameScore.ToString("F2")
            };
        string _dstring = String.Join(", ", _data);
        _dstring += "\n";
        dataLog.logData(_dstring);

    }

}
public class DataLogger
{
 

    private string _currfilename;
    public string curr_fname
    {
        get { return _currfilename; }
    }
    public StringBuilder _filedata;
    public bool stillLogging
    {
        get { return (_filedata != null); }
    }

    public DataLogger(string filename, string header)
    {
        _currfilename = filename;
        _filedata = new StringBuilder(header);
    }

    public void stopDataLog(bool log = true)
    {
        if (log)
        {
            File.AppendAllText(_currfilename, _filedata.ToString());
        }
        _currfilename = "";
        _filedata = null;
    }

    public void logData(string data)
    {
        if (_filedata != null)
        {
            _filedata.Append(data);
        }
    }
}

public class DataLogger_afterbreak
{


    private string _currfilename1;
    public string curr_fname1
    {
        get { return _currfilename1; }
    }
    public StringBuilder _nextfile;
    public bool stillLogging
    {
        get { return (_nextfile != null); }
    }

    public DataLogger_afterbreak(string filename, string header)
    {
        _currfilename1 = filename;
        _nextfile = new StringBuilder(header);
    }

    public void stopDataLog_afterbreak(bool log = true)
    {
        if (log)
        {
            File.AppendAllText(_currfilename1, _nextfile.ToString());
        }
        _currfilename1 = "";
        _nextfile = null;
    }

    public void logData_afterbreak(string data)
    {
        if (_nextfile != null)
        {
            _nextfile.Append(data);
        }
    }
}
static class AppData
{
    static public string dataFolder = "Rawdata";
    static public string blockFolder = "blockdata";
    static public string calibFolder = "calib_data";
    static public string DetailFolder = "Trial ";

    static public string jdfFilename = "Assets\\jeditextformat.txt";
    static public string[] comPorts;

    static public string idPath = null;

    //def
    public static string selectedGame = null;
    public static string selectedMechanism = null;
    public static string hospno = null;
    public static int currentSessionNumber;
    public static string rawDataPath = null;
    public static string rawData = null;
    public static string gameDataPath = null;
    public static string trialDataFileLocationTemp = null;
    public static string usuablitySDP = null;
    public static string usuablityDataCSVPath { get; private set; }


    public static ROM rom;

    //ROM values

    //handle Mech
    public static float handleAngleMax = 0f;
    public static float handleAngleMin = 0f;
    //grip force
    public static float handleGripForce = 0f;


    //gross knob
    public static float grossKnobMax = 0f;
    public static float grossKnobMin = 0f;

    //fine knob
    public static float fineKnobMin = 0f;
    public static float fineKnobMax = 0f;

    //key knob
    public static float keyKnobMin = 0f;
    public static float keyKnobMax = 0f;
    //TripodGrasp
    public static float graspMin = 0f;
    public static float graspMax = 0f;



    //testing purpose
    public static float avg = 0f;
    public static float dist = 0f;
    public static float offset = 0f;
    public static float angle_1 = 0f;
    public static bool offsetRunOnce = false;
    static public double nanosecPerTick = 1.0 / Stopwatch.Frequency;
    static public Stopwatch stp_watch = new Stopwatch();

    public static float timelog;
    public static int current_trial = 0;
    public static int current_block = 0;
    public static bool HyperCubeConnected = false;

    // Arduino related variables
    //static public JediSerialCom jediClient;

    // Incoming data format
    static public string dataFormat;

    // JEDI data buffer
    static public JediDataBuffers dataTime;
    static public JediDataBuffers dataBuffers;

    // Data Logger
    static public DataLogger dlogger;
    static public DataLogger_afterbreak afterLogger;
    public static DateTime trialStartTime { get; set; }
    public static DateTime? trialStopTime { get; set; }
    public static DateTime startTime { get; set; }
    public static HyperCubeMechanism selectedMech { get; set; }
    public static screeningData scrData { get; set; }
    public static float successRate { get; set; }

    public static string trialRawDataFile, trialGameDataFile;
    private static StringBuilder rawDataString = null;
    private static StringBuilder gameDataString = null;

    private static readonly object rawDataLock = new object();
    private static readonly object gameDataLock = new object();

    // public static int currentSessionNumber;



    // UDP Message Handling Variables.
    //static public List<string> msgQ = new List<string>();
    //static public bool logData = false;
    //static public bool exitApp = false;


    public static void loadCurrentSessNo()
    {
        DataManager.dTableSession = DataManager.loadCSV(DataManager.sessionFile);
        currentSessionNumber = DataManager.dTableSession.Rows.Count > 0 ?
            Convert.ToInt32(DataManager.dTableSession.Rows[DataManager.dTableSession.Rows.Count - 1]["SessionNumber"]) + 1 : 1;
    }

    static public double CurrentTime()
    {
        return stp_watch.ElapsedTicks * nanosecPerTick;

    }

    public static void setUsabilityPath(string mech)
    {
        Debug.Log("workinggggggggggggggggggggggg " + mech);
        usuablityDataCSVPath = Path.Combine(usuablitySDP, $"{mech}-usabilityData.csv");
        Debug.Log($"path : {usuablityDataCSVPath}");
    }


    // Start a new trial.
    public static void StartNewTrial()
    {
        Debug.Log("new trial started");

        trialStartTime = DateTime.Now;
        trialStopTime = null;
        selectedMech.NextTrail();
        gameData.moveTime = 0;
        // Set the trial data files.
        StartRawAndAanExecDataLogging();

        // Write trial details to the log file.
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMech.trialNumberDay}",
                $"Trial#Sess: {selectedMech.trialNumberSession}",
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
    }

    public static void StopTrial()
    {
        // Dettach the event handler for data logging.
        // PlutoComm.OnNewPlutoData -= OnNewPlutoDataDataLogging;

        trialStopTime = DateTime.Now;
        // nTargets = (nTargets == 0) ? 1 : nTargets;
        // successRate = 100 * nSuccess / nTargets;
        DataManager.writeUD();

        // Write trial information to the session details file.
        WriteTrialToSessionsFile();
        // Write trial details to the log file.
        string _tdetails = string.Join(" | ",
            new string[] {
                $"Start Time: {trialStartTime:yyyy-MM-ddTHH:mm:ss}",
                $"Stop Time: {trialStopTime:yyyy-MM-ddTHH:mm:ss}",
                $"Trial#Day: {selectedMech.trialNumberDay}",
                $"Trial#Sess: {selectedMech.trialNumberSession}",
                $"Trial SR: {DataManager.successRate}",
                $"TrialRawDataFile: {trialRawDataFile.Split('/').Last()}"
        });
        // Stop Raw and AAN real-time data logging.
        WriteTrialDataToRawDataFile();
        JediSerialPayload.OnNewCubeData -= OnNewCubeDataDataLogging;
        trialRawDataFile = null;

        gameData.moveTime = 0;
    }

    private static void WriteTrialToSessionsFile()
    {
        // Build the trial row.
        string[] trialRow = new string[] {
            // "SessionNumber"
            $"{currentSessionNumber}",
            // "DateTime"
            startTime.ToString(DataManager.DATEFORMAT),
            // "TrialNumberDay"
            $"{selectedMech.trialNumberDay}",
            // "TrialNumberSession"
            $"{selectedMech.trialNumberSession}",
            // "TrialStartTime"
            trialStartTime.ToString(DataManager.DATEFORMAT),
            // "TrialStopTime"
            trialStopTime?.ToString(DataManager.DATEFORMAT),
            // "TrialRawDataFile"
            //trialRawDataFile.Split(new string[] { "/data/" }, StringSplitOptions.None)[1],
            "test",
            // "Mechanism"
            AppData.selectedMechanism, 
            // "GameName"
            selectedGame,
            // "GameParameter"
            null,
            // "GameSpeed"
            "10",
            // "SuccessRate"
            $"{successRate:F3}",
            //gameTime
            gameData.moveTime.ToString()
        };

        // Write the trial row to the session file.
        using (StreamWriter sw = new StreamWriter(DataManager.sessionFile, true, Encoding.UTF8))
        {
            // Write the trial row to the session file.
            sw.WriteLine(string.Join(",", trialRow));
        }
    }

    public static void StartRawAndAanExecDataLogging()
    {
        // Set the file name.
        trialRawDataFile = DataManager.GetTrialRawDataFileName(
            currentSessionNumber,
            selectedMech.trialNumberDay,
            AppData.selectedGame,
            AppData.selectedMechanism);
        trialGameDataFile = DataManager.GetTrialGameDataFileName(
            currentSessionNumber,
            selectedMech.trialNumberDay,
            AppData.selectedGame,
            AppData.selectedMechanism);
        // Initialize the string builders.
        rawDataString = new StringBuilder();
        // Write pre-header and header information
        rawDataString.AppendLine($":Device: HyperCube");
        rawDataString.AppendLine($":Mechanism: {AppData.selectedMechanism}");
        rawDataString.AppendLine($":Game: {selectedGame}");
        rawDataString.AppendLine($":TrialStartTime: {trialStartTime:yyyy-MM-ddTHH:mm:ss}");
        rawDataString.AppendLine($":TrialNumberDay: {selectedMech.trialNumberDay}");
        if ((AppData.selectedMechanism != JediSerialPayload.MECHANISMS[6]) && AppData.selectedMechanism != JediSerialPayload.MECHANISMS[7]) rawDataString.AppendLine($":AROM: [{selectedMech.CurrentArom[0]:F3},{selectedMech.CurrentArom[1]:F3}]");
        rawDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));

        // Attach the event handler for data logging.
        JediSerialPayload.OnNewCubeData += OnNewCubeDataDataLogging;
    }
    public static void StartGameDataLogging()
    {
        trialGameDataFile = DataManager.GetTrialGameDataFileName(
            currentSessionNumber,
            selectedMech.trialNumberDay,
            AppData.selectedGame,
            AppData.selectedMechanism);
        // Initialize the string builders.
        gameDataString = new StringBuilder();
        // Write pre-header and header information
        gameDataString.AppendLine($":Device: HyperCube");
        gameDataString.AppendLine($":Mechanism: {AppData.selectedMechanism}");
        gameDataString.AppendLine($":Game: {selectedGame}");
        gameDataString.AppendLine($":TrialStartTime: {trialStartTime:yyyy-MM-ddTHH:mm:ss}");
        gameDataString.AppendLine($":TrialNumberDay: {selectedMech.trialNumberDay}");
        if ((AppData.selectedMechanism != JediSerialPayload.MECHANISMS[6]) && AppData.selectedMechanism != JediSerialPayload.MECHANISMS[7]) rawDataString.AppendLine($":AROM: [{selectedMech.CurrentArom[0]:F3},{selectedMech.CurrentArom[1]:F3}]");
        gameDataString.AppendLine(string.Join(",", DataManager.RAWFILEHEADER));

        // Attach the event handler for data logging.
        JediSerialPayload.OnNewCubeData += OnNewCubeDataDataLogging;
    }

    public static void OnNewCubeDataDataLogging()
    {
        lock (rawDataLock)
        {
            if (rawDataString == null)
            {
                UnityEngine.Debug.LogWarning("rawDataString is null, skipping logging.");
                return;
            }

            // Device data
            rawDataString.Append($"{hyper1.timer_:F3},");
            rawDataString.Append($"{JediSerialPayload.force_1},");
            rawDataString.Append($"{JediSerialPayload.force_2},");
            rawDataString.Append($"{JediSerialPayload.totalForce},");
            rawDataString.Append($"{JediSerialPayload.angle_1},");
            rawDataString.Append($"{JediSerialPayload.angle_2},");
            rawDataString.Append($"{JediSerialPayload.angle_3},");
            rawDataString.Append($"{JediSerialPayload.angle_4},");
            rawDataString.Append($"{JediSerialPayload.distance_1},");
            rawDataString.Append($"{JediSerialPayload.distance_2},");
            rawDataString.Append($"{JediSerialPayload.avgBtwDistance},");
            rawDataString.Append($"{JediSerialPayload.button_1},");
            rawDataString.Append($"{JediSerialPayload.button_2},");
            rawDataString.Append($"{JediSerialPayload.button_3},");
            rawDataString.Append($"{JediSerialPayload.button_4},");
            rawDataString.Append($"{JediSerialPayload.button_5},");
            rawDataString.Append($"{JediSerialPayload.button_6},");
            rawDataString.Append($"{JediSerialPayload.button_7},");

            // End of line
            rawDataString.Append("\n");
        }
    }

    private static void WriteTrialDataToRawDataFile()
    {
        string _dir = Path.GetDirectoryName(trialRawDataFile);
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        lock (rawDataLock)  // locking
        {
            using (StreamWriter sw = new StreamWriter(trialRawDataFile, false, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
        }

    }
    
    private static void WriteTrialDataToGameDataFile()
    {
        string _dir = Path.GetDirectoryName(trialRawDataFile);
        if (!Directory.Exists(_dir)) Directory.CreateDirectory(_dir);

        lock (rawDataLock)  // locking
        {
            using (StreamWriter sw = new StreamWriter(trialGameDataFile, false, Encoding.UTF8))
            {
                sw.Write(rawDataString.ToString());
            }
            rawDataString.Clear();
            rawDataString = null;
        }

    }
}

public class screeningData
{
    public DataTable dtableUtilityData;
    public string[] mechanismsUD = new string[] { "HGF", "GKNOB", "FKNOB", "KKNOB", "TGRASP", "PGRASP","BUTTONS" };
    public Dictionary<string, float> MASR = new Dictionary<string, float>();

    public string mech;
    public screeningData()
    {
            for (int i = 0; i < mechanismsUD.Length; i++)
            {
                string mech = mechanismsUD[i];
                string usabilityCSVPath = Path.Combine(AppData.usuablitySDP, $"{mech}-usabilityData.csv");

                if (File.Exists(usabilityCSVPath))
                {
                    dtableUtilityData = DataManager.loadCSV(usabilityCSVPath);
                    List<float> Result = new List<float>();

                    foreach (DataRow row in dtableUtilityData.Rows)
                    {
                        if (float.TryParse(row["AvgSR"].ToString(), out float res))
                        {
                            Debug.Log(res);
                            Result.Add(res);
                        }
                    }

                    if (Result.Count >= 5)
                    {
                        MASR.Add(mech, Result[4]);
                    }
                    else
                    {
                        // File exists but doesn’t have 5 valid entries
                        MASR.Add(mech, 0f);
                        Debug.Log($"{mech}: file exists but not enough data → stored 0");
                    }
                }
                else
                {
                    // File does not exist at all
                    MASR.Add(mech, 0f);
                    Debug.Log($"{mech}: file not found → stored 0");
                }
            }

    }
}

public class HyperCubeMechanism
{
    // public static string MECHPATH { get; private set; } = DataManager.mechPath;
    public string name { get; private set; }
    public string side { get; private set; }
    public bool aromCompleted { get; private set; }
    public ROM oldRom { get; private set; }
    public ROM newRom { get; private set; }
    public ROM currRom { get => newRom.isSet ? newRom : (oldRom.isSet ? oldRom : null); }
    public float currSpeed { get; private set; } = -1f;
    // Trial details for the mechanism.
    public int trialNumberDay { get; private set; }
    public int trialNumberSession { get; private set; }
    public int totalTrialNumber { get; private set; }


    public HyperCubeMechanism(string name, int sessno)
    {
        this.name = name?.ToUpper() ?? string.Empty;
        // this.side = side;
        // if (name != JediSerialPayload.MECHANISMS[6] && name != JediSerialPayload.MECHANISMS[7])
        // {
        oldRom = new ROM(this.name);
        newRom = new ROM();
        Debug.Log($"session number in:{sessno}, mech :{this.name}");
        // }

        aromCompleted = false;
        // this.side = side;
        currSpeed = -1f;
        Debug.Log($"session number:{sessno}, mech :{this.name}");
        UpdateTrialNumbers(sessno);
    }

    public bool IsMechanism(string mechName) => string.Equals(name, mechName, StringComparison.OrdinalIgnoreCase);

    public bool IsSide(string sideName) => string.Equals(side, sideName, StringComparison.OrdinalIgnoreCase);

    public bool IsSpeedUpdated() => currSpeed > 0;


    public void NextTrail()
    {
        trialNumberDay += 1;
        trialNumberSession += 1;
    }

    public float[] CurrentArom => currRom == null ? null : new float[] { currRom.aromMin, currRom.aromMax };
    public float[] CurrentAromHGF => currRom == null ? null : new float[] { currRom.aromMin, currRom.aromMax, currRom.gripForce };



    public void ResetAromValues()
    {
        newRom.SetArom(0, 0);
        aromCompleted = false;
    }

    public void ResetAromValues(float force = 0)
    {
        newRom.SetArom(0, 0, 0);
        aromCompleted = false;
    }



    public void SetNewAromValues(float amin, float amax)
    {
        newRom.SetArom(amin, amax);
        if (amin != 0 || amax != 0) aromCompleted = true;
        if (newRom.mechanism == null)
        {
            newRom.SetMechanism(this.name);
        }
    }
    public void SetNewAromValues(float amin, float amax, float force)
    {
        newRom.SetArom(amin, amax, force);
        if (amin != 0 || amax != 0) aromCompleted = true;
        if (newRom.mechanism == null)
        {
            newRom.SetMechanism(this.name);
        }
    }

    public void SaveAssessmentData()
    {
        if (aromCompleted)
        {
            // Save the new ROM values to the file.
            newRom.WriteToAssessmentFile();
        }
    }
    /*
     * Function to update the trial numbers for the day and session for the mechanism for today.
     */
    public void UpdateTrialNumbers(int sessno)
    {
        var today = DateTime.Now.Date;
        var mechanismName = this.name;
        DataManager.dTableSession = DataManager.loadCSV(DataManager.sessionFile);

        // Filter the rows manually instead of using AsEnumerable
        List<DataRow> selRows = new List<DataRow>();
        foreach (DataRow row in DataManager.dTableSession.Rows)
        {
            if (DateTime.TryParseExact(row["DateTime"].ToString(), DataManager.DATEFORMAT, CultureInfo.InvariantCulture, DateTimeStyles.None, out DateTime rowDate)
                && rowDate.Date == today
                && row["Mechanism"].ToString() == mechanismName)
            {
                selRows.Add(row);
            }
        }

        if (selRows.Count == 0)
        {
            trialNumberDay = 0;
            trialNumberSession = 0;
            return;
        }

        trialNumberDay = selRows.Max(row => Convert.ToInt32(row["TrialNumberDay"]));

        // Filter again for session-specific trial numbers
        List<DataRow> sessionRows = new List<DataRow>();
        foreach (DataRow row in selRows)
        {
            if (int.TryParse(row["SessionNumber"].ToString(), out int sessionNumber) && sessionNumber == sessno)
            {
                sessionRows.Add(row);
            }
        }

        if (sessionRows.Count == 0)
        {
            trialNumberSession = 0;
            return;
        }

        UnityEngine.Debug.Log(sessionRows.Count);
        trialNumberSession = sessionRows.Max(row => Convert.ToInt32(row["TrialNumberSession"]));
    }

}


public static class JediSerialCom
{
    static public bool stop;
    static public bool pause;
    static public SerialPort serPort;
    static private Thread reader;
    static private uint _count;
    static public uint count

    {
        get { return _count; }
    }
    static public bool newData;
    static public int annotation;



    //public JediSerialCom(string port)
    //{
    //    serPort = new SerialPort();
    //    // Allow the user to set the appropriate properties.
    //    serPort.PortName = port;
    //    serPort.BaudRate = 115200;
    //    serPort.Parity = Parity.None;
    //    serPort.DataBits = 8;
    //    serPort.StopBits = StopBits.One;
    //    serPort.Handshake = Handshake.None;
    //    serPort.DtrEnable = true;

    //    // Set the read/write timeouts
    //    serPort.ReadTimeout = 500;
    //    serPort.WriteTimeout = 500;
    //    reader = new Thread(serialreaderthread);

    //}

    static public void InitSerialComm(string port)
    {
        serPort = new SerialPort();
        // Allow the user to set the appropriate properties.
        serPort.PortName = port;
        serPort.BaudRate = 115200;
        serPort.Parity = Parity.None;
        serPort.DataBits = 8;
        serPort.StopBits = StopBits.One;
        serPort.Handshake = Handshake.None;
        serPort.DtrEnable = true;

        // Set the read/write timeouts
        serPort.ReadTimeout = 250;
        serPort.WriteTimeout = 250;
    }

    static public void Connect()
    {
        stop = false;
        if (serPort.IsOpen == false)
        {
            try
            {
                serPort.Open();
            }
            catch (Exception ex)
            {
                Debug.Log("exception: " + ex);
            }
            // Create a new thread to read the serial port data.
            reader = new Thread(serialreaderthread);
            reader.Priority = System.Threading.ThreadPriority.AboveNormal;
            reader.Start();
        }
    }

    static public void Disconnect()
    {
        stop = true;
        if (serPort.IsOpen)
        {
            reader.Abort();
            serPort.Close();
        }
    }


    static public void resetCount()
    {
        _count = 0;
    }

    static private void serialreaderthread()
    {
        byte[] _floatbytes = new byte[4];

        // start stop watch.
        while (stop == false)
        {

            // Do nothing if in pause
            if (pause)
            {
                continue;
            }
            try
            {

                // Read full packet.
                if (readFullSerialPacket())
                {

                    _count++;
                    JediSerialPayload.updateData();
                    newData = true;
                    AppData.HyperCubeConnected = true;
                    // Update data buffers.
                    if (AppData.dataBuffers != null)
                    {

                        AppData.dataTime.Add(new float[] { (float)AppData.CurrentTime() });
                        AppData.dataBuffers.Add(JediSerialPayload.data);
                        // JediSerialPayload.RaiseNewCubeData();
                    }
                    // Debug.Log(AppData.dlogger);
                    //// Check if data is to be logged.
                    if (AppData.dlogger != null)
                    {

                        string traildata = hyper1.timer_ + JediSerialPayload.GetFormatedData(JediSerialPayload.data) + "\n";

                        AppData.dlogger.logData(traildata);
                        // Debug.Log(traildata);
                    }
                    //if (AppData.afterLogger != null)
                    //{

                    //    string traildata = protocol.timestart + JediSerialPayload.GetFormatedData(JediSerialPayload.data) + "," + AppData.current_trial + "," + AppData.current_block + "\n";
                    //    //  Debug.Log(traildata);
                    //    AppData.afterLogger.logData_afterbreak(traildata);

                    //}

                    else
                    {

                        annotation = 0;
                    }
                }
                else
                {
                    AppData.HyperCubeConnected = false;
                    Debug.Log($" hypercube : {AppData.HyperCubeConnected}");
                }
            }
            catch (TimeoutException)
            {

                continue;
            }
        }
        serPort.Close();
    }

    // Read a full serial packet.
    static private bool readFullSerialPacket()
    {
        int chksum = 0;
        int _chksum;
        int rawbyte;
        //  Debug.Log(serPort.ReadByte().ToString());
        // Header bytes
        if ((serPort.ReadByte() == 0xFF) && (serPort.ReadByte() == 0xFF))
        {

            JediSerialPayload.count++;
            chksum = 255 + 255;
            //  No. of bytes
            JediSerialPayload.plSz = serPort.ReadByte();
            chksum += JediSerialPayload.plSz;

            // read payload
            for (int i = 0; i < JediSerialPayload.plSz - 1; i++)
            {
                rawbyte = serPort.ReadByte();
                chksum += rawbyte;
                JediSerialPayload.payload[i] = rawbyte;
                JediSerialPayload.payloadBytes[i] = (byte)rawbyte;
            }

            //    De.Log("ping");
            // ensure check sum is correct.
            // Debug.Log(JediSerialPayload.plSz);
            _chksum = serPort.ReadByte();
            // Debug.Log(_chksum == (chksum & 0xFF));
            return (_chksum == (chksum & 0xFF));

        }


        //    Debug.Log("Wrong Data");
        return false;

    }
}

public class JediDataBuffers
{
    static public readonly int maxBufferLength = 1000;
    public int noOfChannels { get; private set; }
    private float[,] _rawData;
    public float[,] rawData
    {
        get { return _rawData; }
    }
    public int head { get; private set; }
    public int tail { get; private set; }
    public int count { get; private set; }
    public string[] channelLabels { get; private set; }

    public JediDataBuffers(int noChannels, string[] chLbls)
    {
        noOfChannels = noChannels;
        _rawData = new float[noChannels, maxBufferLength];
        channelLabels = (string[])chLbls.Clone();
        head = maxBufferLength - 1;
        tail = 0;
        count = 0;
    }

    public void Add(float[] newdata)
    {
        // Update tail and start
        head = (head + 1) % maxBufferLength;
        for (int i = 0; i < newdata.Length; i++)
        {
            _rawData[i, head] = newdata[i];
        }
        if (count == maxBufferLength)
        {
            tail = (tail + 1) % maxBufferLength;
        }
        else
        {
            count++;
        }
    }

    public void Add(List<object> newdata)
    {
        // Update tail and start
        head = (head + 1) % maxBufferLength;
        for (int i = 0; i < newdata.Count; i++)
        {
            _rawData[i, head] = JediDataFormat.GetFloatValue(i, newdata[i]);
        }
        if (count == maxBufferLength)
        {
            tail = (tail + 1) % maxBufferLength;
        }
        else
        {
            count++;
        }

    }
  
}




