import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class TrinityAminoAcidTosqlLite
{
    public static void main(String args[])
    {
        try{
            // Open Files needed     
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            File file = new File(args[0]); 
            Scanner scanner = new Scanner(file);
            String ToPrint = args[1]; 
            String PrintSent = "verbose";
            String ProgressCounterSENT = "counter";
            String strLine;
            // Set Varibles needed for Parser  
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
            String TrinityTranscriptIndexHolder = "";
            String UniprotMatchCheck = "";
            int ArrayInitialize2=0;
            String ParsedMascotHolder = "";
            int InCorrectCounter = 0;
            String ParsedMascotIndexCheck = "";
            int MatchFoundflag = 0;
            int MatchFoundCounter = 0;
            int NotFoundCounter = 0;
            String removecomment = "";
            String TrinityTranscriptIDCheck = "";
            String TrinityStrandForDBASE = "";
            String TrinityPathForDBASE = "";
            char FirstChHolder;
            char FirstChHolderForWhile;
            char SentCheck = '>';
            String delimiter = "\\>";
            String delimiter2 = ":";
            String TrinityTranscriptforDBASE = "";
            String TrinityTypeForDBASE = "";
            String TrinityAALengthForDBASE = "";
            int sentValueforPrint = 0;
            String TempSeqHold = "";
            String SeqForDBASE = "";
            int p = 0;
            String[] temp;
            int SentforDBASEadd = 0;
            String TrinityTranscriptIndexHolder2 ="";
            String TrinityTranscriptIDCheck2 = "";
            int StartPrintSent = 0;
            int shiftsent = 0;
            
            
            //sqllite database
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            stat.executeUpdate("delete from TrinityTranscript;");
            
            
            
            //read into file
            while ((strLine = br.readLine()) != null)   
                {
                    ArrayInitialize++;
                }
            String TrinityTranscriptTotalFile[] = new String[ArrayInitialize];
            
            while(scanner.hasNextLine())
                {
                    TrinityTranscriptTotalFile[LineCounter] = scanner.nextLine();
                    LineCounter++;
                }
            
            PreparedStatement prep = conn.prepareStatement("insert into TrinityTranscript values (?, ?, ?, ?, ?, ?);");
            
            //for loop, reads through file array, committs needed information
            for (int i=0; i<LineCounter; i++)
                {
					if (ToPrint.equals(ProgressCounterSENT))
                        {
                            if (i%1000 == 0)
                                {
                                    System.out.println("Processed Entry:" + i);
                                }
                        }
                    TrinityTranscriptIndexHolder = TrinityTranscriptTotalFile[i];
                    StringTokenizer st1 = new StringTokenizer(TrinityTranscriptIndexHolder);
                    TrinityTranscriptIDCheck = st1.nextToken();
                    FirstChHolder=TrinityTranscriptIDCheck.charAt(0);		
                    if(FirstChHolder==SentCheck)
                        {
                            temp = TrinityTranscriptIDCheck.split(delimiter);
                            TrinityTranscriptforDBASE=temp[1];
                            sentValueforPrint = 1; 
                            TrinityTranscriptIDCheck = st1.nextToken();
                            TrinityTranscriptIDCheck = st1.nextToken();
                            TrinityTranscriptIDCheck = st1.nextToken();
                            TrinityTranscriptIDCheck = st1.nextToken();
                            TrinityTranscriptIDCheck = st1.nextToken();
                            temp = TrinityTranscriptIDCheck.split(delimiter2);
                            TrinityTypeForDBASE=temp[1];
                            TrinityTranscriptIDCheck = st1.nextToken();
                            temp = TrinityTranscriptIDCheck.split(delimiter2);
                            TrinityAALengthForDBASE=temp[1];
                            TrinityStrandForDBASE = st1.nextToken();
                            TrinityPathForDBASE = st1.nextToken();
                        }		 
                    else
                        {
                            while (sentValueforPrint ==1 && p<LineCounter)
                                {
                                    if (p==LineCounter-1)
                                        {
                                            sentValueforPrint=0;
                                            prep.setString(1,TrinityTranscriptforDBASE);
                                            prep.setString(2,TrinityTypeForDBASE);
                                            prep.setString(3,TrinityAALengthForDBASE);
                                            prep.setString(4,TrinityStrandForDBASE);
                                            prep.setString(5,TrinityPathForDBASE);
                                            prep.setString(6,SeqForDBASE);
                                            prep.addBatch();
                                        }
                                    else
                                        {
                                            p++;
                                            TrinityTranscriptIndexHolder2 = TrinityTranscriptTotalFile[p];
                                            StringTokenizer st2 = new StringTokenizer(TrinityTranscriptIndexHolder2);
                                            TrinityTranscriptIDCheck2 = st2.nextToken();
                                            FirstChHolderForWhile=TrinityTranscriptIDCheck2.charAt(0);
                                            if(FirstChHolderForWhile==SentCheck)
                                                {
                                                    sentValueforPrint=0;
                                                    prep.setString(1,TrinityTranscriptforDBASE);
                                                    prep.setString(2,TrinityTypeForDBASE);
                                                    prep.setString(3,TrinityAALengthForDBASE);
                                                    prep.setString(4,TrinityStrandForDBASE);
                                                    prep.setString(5,TrinityPathForDBASE);
                                                    prep.setString(6,SeqForDBASE);
                                                    prep.addBatch();
                                                    TempSeqHold= "";	
                                                    shiftsent =1;
                                                    i=p-1;
                                                }
                                            else
                                                {
                                                    TempSeqHold= TempSeqHold + TrinityTranscriptTotalFile[p];
                                                    SeqForDBASE=TempSeqHold; 
                                                }
                                            
                                        }
                                }
                        }
                    
                }
            
            conn.setAutoCommit(false);
            prep.executeBatch();
            conn.setAutoCommit(true);
            
            if (ToPrint.equals(PrintSent))
                {
                    ResultSet rs = stat.executeQuery("select * from TrinityTranscript;");
                    while (rs.next()) {
                        System.out.println("TrinityModelName = " + rs.getString("TrinityAminoAcidID"));
                        System.out.println("TrinityPredictionType = " + rs.getString("PredicitonType")); 
                        System.out.println("TrinityModelLength = " + rs.getString("Length"));
                        System.out.println("TrinityStrandPredicition = " + rs.getString("Strand"));
                        System.out.println("TrinityModelParentPath = " + rs.getString("Path"));
                        System.out.println("TrinityProteinSeqeunce = " + rs.getString("AminoAcid_sequence"));
                    }	
                }	
            
            
            
            
            //Close the input stream
            in.close();
            conn.close();
            
            
            
            
            
        }catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}




