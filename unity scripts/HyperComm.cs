using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

public static class JediSerialPayload
{


    public static readonly string[] MECHANISMS = new string[] { "NOMECH", "HGF", "GKNOB", "FKNOB", "KKNOB", "TGRASP", "PGRASP", "BUTTONS" };
    public static readonly string[] MECHANISMSTEXT = new string[] { "NOMECH", "Handle Grip Force", "Gross knob", "Fine knob", "key knob", "tripod grasp", "pinch grasp", "Buttons" };

    static public uint count;
    static public int plSz = 0;
    static public byte status = 0;
    //static public byte[] errorval = new byte[] { 0, 0x00 };
    static public int[] payload = new int[256];
    static public byte[] payloadBytes = new byte[256];
    static public List<object> data = new List<object>();
    static private int MovingAverageLength = 5;
    static private int counter;
    static private float movingAverage;
    public delegate void CubeNewDataEvent();
    public static event CubeNewDataEvent OnNewCubeData;

    public static void RaiseNewCubeData()
    {
        OnNewCubeData?.Invoke();
    }
    static public float force_1
    {
        get
        {
            return (float.Parse(data[0].ToString()));
        }
    }
    static public float force_2
    {
        get
        {
            return (float.Parse(data[1].ToString()));
        }
    }
    static public float totalForce
    {
        get
        {
            return (force_1 + force_2);
        }
    }
    static public float angle_1
    {
        get
        {
            return (float.Parse(data[2].ToString()));
        }
    }
    static public float angle_2
    {
        get
        {
            return -(float.Parse(data[3].ToString()));
        }
    }
    static public float angle_3
    {
        get
        {
            return -(float.Parse(data[4].ToString()));
        }
    }
    static public float angle_4
    {
        get
        {
            return (float.Parse(data[5].ToString()));
        }
    }
    static public float distance_1
    {
        get
        {
            return (float.Parse(data[6].ToString()));
        }
    }
    static public float distance_2
    {
        get
        {
            return (float.Parse(data[7].ToString()));
        }
    }
    static public float btwDistance
    {
        get
        {
            return (11.2f - (distance_1 + distance_2));
        }
    }
    static public int button_1
    {
        get
        {
            return (int.Parse(data[8].ToString()));
        }
    }
    static public int button_2
    {
        get
        {
            return (int.Parse(data[9].ToString()));
        }
    }
    static public int button_3
    {
        get
        {
            return (int.Parse(data[10].ToString()));
        }
    }
    static public int button_4
    {
        get
        {
            return (int.Parse(data[11].ToString()));
        }
    }
    static public int button_5
    {
        get
        {
            return (int.Parse(data[12].ToString()));
        }
    }
    static public int button_6
    {
        get
        {
            return (int.Parse(data[13].ToString()));
        }
    }
    static public int button_7
    {
        get
        {
            return (int.Parse(data[14].ToString()));
        }
    }
    static public float avgBtwDistance
    {
        get
        {
            return MovingAverage(btwDistance);
        }
    }
    static private bool IsFormatStringCorrect(string dataformat)
    {
        foreach (char c in dataformat)
        {
            if (Array.Exists(JediDataFormat.FormatChars, chr => chr == c) == false)
            {
                return false;
            }
        }
        return true;
    }

    static public bool updateData()
    {
        // Ensure that the payload size is equal to the expect sizes for the
        //given data format.
        //Debug.Log(JediDataFormat.dformat.Length );
        if ((plSz - 1 == JediDataFormat.dataSize))
        {
            // Debug.Log(JediDataFormat.dformat.Length && JediDataFormat.dformat.Length < 16);
            int byteArrayInx = 0;
            data.Clear();
            for (int i = 0; i < 15; i++)
            {
                switch (JediDataFormat.dataTypes[i])
                {
                    case 'b':
                        data.Add(JediSerialPayload.payloadBytes[byteArrayInx]);
                        break;
                    case 'i':
                        data.Add(System.BitConverter.ToUInt16(JediSerialPayload.payloadBytes, byteArrayInx));
                        break;
                    case 'f':
                        data.Add(System.BitConverter.ToSingle(JediSerialPayload.payloadBytes, byteArrayInx));
                        break;
                }
                byteArrayInx += JediDataFormat.FormatCharSize[Array.IndexOf(JediDataFormat.FormatChars, JediDataFormat.dataTypes[i])];
            }
            RaiseNewCubeData();

            foreach (object o in data)
            {
                //  Debug.Log(o);
                //Debug.Log(" ");
            }
            // Debug.Log("\r");
            return true;
        }
        else
        {
            Debug.Log("\r no data coming in.");
            Debug.Log($"size of plsz-{ plSz}, jedi-{JediDataFormat.dataSize}");
            AppData.HyperCubeConnected = false;
            Debug.Log($"size {AppData.HyperCubeConnected}");
            return false;
        }
    }


    static public string GetFormatedData(List<object> data)
    {
        string _dstring = AppData.CurrentTime().ToString("G17");
        for (int i = 0; i < data.Count; i++)
        {
            switch (JediDataFormat.dataTypes[i])
            {
                case 'b':
                    _dstring += "," + ((byte)data[i]).ToString();
                    break;
                case 'i':
                    _dstring += "," + ((UInt16)data[i]).ToString();
                    break;
                case 'f':
                    _dstring += "," + ((float)data[i]).ToString("G17");
                    break;
            }

        }
        //_dstring += "\n";
        return _dstring;
    }

    static public string GetFormatedDataWithLabels(List<object> data)
    {
        StringBuilder _strbldr = new StringBuilder();
        _strbldr.AppendLine($"    Time\t: {AppData.CurrentTime()}");
        for (int i = 0; i < data.Count; i++)
        {
            _strbldr.AppendLine($"[{JediDataFormat.dataTypes[i]}] {JediDataFormat.dataLabels[i]}\t: {data[i]}");

        }
        return _strbldr.ToString();
    }
    static private float MovingAverage(float values)
    {
        counter++;


        if (counter > MovingAverageLength)
        {
            movingAverage = movingAverage + (values - movingAverage) / (MovingAverageLength + 1);
        }
        else
        {
            movingAverage += values;

            if (counter == MovingAverageLength)
            {
                movingAverage = movingAverage / counter;

            }
        }
        return movingAverage;
    }
}


public static class ConnectToHypercube
{
    public static string _port;
    public static bool isHypercube = false;

    public static void Connect(string port)
    {
        _port = port;
        if (_port == null)
        {
            _port = "COM3";
            JediSerialCom.InitSerialComm(_port);
        }
        else
        {
            JediSerialCom.InitSerialComm(_port);
        }
        if (JediSerialCom.serPort != null)
        {
            if (JediSerialCom.serPort.IsOpen == false)
            {
                UnityEngine.Debug.Log(_port);
                JediSerialCom.Connect();
            }
        }

    }
    public static void disconnect()
    {
        ConnectToHypercube.isHypercube = false;
        JediSerialCom.Disconnect();
    }
}