import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class tmhmmtoMYSQLlite
{
    public static void main(String args[])
    {
        try{
            
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            File file = new File(args[0]); 
            Scanner scanner = new Scanner(file);
            String ToPrint = args[1]; 
            String ProgressCounterSENT = "counter";
            String PrintSent = "verbose";
            String strLine;
            int ArrayInitialize=0;
            int LineCounter=0;
            int LineCounter1=0;
            int LineCounter2=0;
            String BlastNameHolder = "";
            String DatabaseIndexHolder = "";
            int FoundSent = 0;
            String BlastMatchCheck = "";
            String HeapForPrint = "";
            int FoundIndex=0;
            int NotFoundIndex = 0;
            String BlastIndexCheck ="";
            String tmhmmIndexHolder = "";
            String UniprotMatchCheck = "";
            int ArrayInitialize2=0;
            String ParsedMascotHolder = "";
            int InCorrectCounter = 0;
            String ParsedMascotIndexCheck = "";
            int MatchFoundflag = 0;
            int MatchFoundCounter = 0;
            int NotFoundCounter = 0;
            String removecomment = "";
            String tmhmmqueryprotidToken = "";
            String tmhmmLengthToken = "";
            String tmhmmScore = "";
            String tmhmmFirst60 = "";
            String tmhmmPredHel = "";
            String tmhmmTopology = "";
            
            //sqllite database 
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            stat.executeUpdate("delete from tmhmm;");
 
            //read in file
            while ((strLine = br.readLine()) != null)   
                {
                    ArrayInitialize++;
                }
            String tmhmmTotalFile[] = new String[ArrayInitialize];
            
            while(scanner.hasNextLine())
                {
                    tmhmmTotalFile[LineCounter] = scanner.nextLine();
                    LineCounter++;
                }
            
            
            
            PreparedStatement prep = conn.prepareStatement("insert into tmhmm values (?, ?, ?, ?);");
            
            //for loop cycles through entires tokenizes and commits to dataebase
            for (int i=0; i<LineCounter; i++)
                {
                    
                    if (ToPrint.equals(ProgressCounterSENT))
                        {
                            if (i%1000 == 0)
                                {
                                    System.out.print("\rProcessed Entry:" + i + "   ");
                                }
                        }
                    tmhmmIndexHolder = tmhmmTotalFile[i];
                    StringTokenizer st1 = new StringTokenizer(tmhmmIndexHolder);
                    
                    tmhmmqueryprotidToken = st1.nextToken();
                    tmhmmLengthToken = st1.nextToken();   
                    tmhmmScore = st1.nextToken();
                    tmhmmFirst60 = st1.nextToken();
                    tmhmmPredHel = st1.nextToken();
                    tmhmmTopology = st1.nextToken();
                    
                    prep.setString(1,tmhmmqueryprotidToken);
                    prep.setString(2,tmhmmScore);
                    prep.setString(3,tmhmmPredHel);
                    prep.setString(4,tmhmmTopology);
                    prep.addBatch();	
                    
                }
            
            conn.setAutoCommit(false);
            prep.executeBatch();
            conn.setAutoCommit(true);
            
            
            
            if (ToPrint.equals(PrintSent))
                {
                    ResultSet rs = stat.executeQuery("select * from tmhmm;");
                    while (rs.next()) {
                        System.out.println("TrintiyID = " + rs.getString("queryprotid"));
                        System.out.println("tmhmmScore = " + rs.getString("Score"));
                        System.out.println("PredictedHelixes = " + rs.getString("PredHel"));
                        System.out.println("TransmembraneTopology = " + rs.getString("Topology"));
                        
                    }	
                }
               
   
            //Close the input stream
            in.close();
            conn.close();
            
            System.out.println("Done");
            System.exit(0);
            
            
            
        }catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);

        }
    }
}

