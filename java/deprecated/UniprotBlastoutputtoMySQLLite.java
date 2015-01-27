import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.*;

class UniprotBlastoutputtoMySQLLite
{
    public static void main(String args[])
    {

        String usage = "args needed: blast.outfmt6 (blastp|blastx) (Trembl|Swissprot) (verbose|counter)";
        if (args.length != 4
            ||
            (! (args[1].equals("blastp") || args[1].equals("blastx")))
            ||
            (! (args[2].equals("Trembl") || args[2].equals("Swissprot")))
            ||
            (! (args[3].equals("verbose") || args[3].equals("counter")))
            ) {
            
            System.err.println(usage);
            System.exit(2);
        }
        
        // option checking

        try{
            // Open Files needed and create the outfiles for each stratification  
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            FileInputStream fstream2 = new FileInputStream(args[0]);
            DataInputStream in2 = new DataInputStream(fstream2);
            BufferedReader br2 = new BufferedReader(new InputStreamReader(in2));
            File file = new File(args[0]); 
            Scanner scannertotal = new Scanner(file);
            Scanner scanner = new Scanner(file);


            String TremblSent = "Trembl";
            String SwissSent = "Swissprot";

            String blastPorX = args[1];
            
            
            String SwissorTremblCheck = args[2]; 
            String ToPrint = args[3]; 

			String DatabaseforStore = "";
            
            int PrintSent = 0;
            
            if (SwissorTremblCheck.equals(SwissSent))
                {
                    PrintSent=1;
					DatabaseforStore = "Swissprot";
                }
            else if (SwissorTremblCheck.equals(TremblSent))
                {
                    PrintSent=1;
					DatabaseforStore = "Trembl";
                }
            else
                {
                    System.out.println("Database Not Specified, ID identification not avlaible Please specify swissprot for the swissprot database enteries or  for EMBL uniprot");
                    System.exit(0);
                }
            String PrintMYSQLSent = "verbose";
            String ProgressCounterSENT = "counter";
            String strLine;
            // Set Varibles needed for Parsing/Tokenization and Comparsion
            int ArrayInitialize=0;
            int SentCounter=2;
            int AccessionCounter=2;
            int KeptTopHitsCounter=0;
            int TopHitSent=50;
            int LineCounter=0;
            int TopNHitCounter=0;
            String SingletHeap = "";
            String BlastTokenHolder;
            String BlastTokenHolder2;
            String DeReplicateTokenHolder;
            String DeReplicateQueryTokenCurrentLine;
            String DeReplicateQueryTokenNextLine;
            String BlastQueryNameToken;
            String BlastAcessionNameToken;
            String BlastPercentIdenityToken;
            String BlastAlignemntLengthToken;
            String BlastMismatchToken;
            String BlastGapOpenToken;
            String BlastQueryStartToken;
            String BlastQueryEndToken; 
            String BlastSubjectStartToken;
            String BlastSubjectEndToken;
            String BlastEvalueToken;
            String BlastBitScoreToken;
            String DeReplicateTokenHolder2;
            String DeReplicateTokenHolder3;
            String DeReplicateQueryTokenCurrentLine2;
            String DeReplicateQueryTokenNextLine2;
            String DeReplicatedAccessionTokenCurrentLine;
            String DeReplicatedAccessionTokenNextLine;
            String DeReplicatedAccessionTokenCurrentLine2;
            String DeReplicatedAccessionTokenNextLine2;
            String BlastQueryNameToken2;
            String BlastAcessionNameToken2;
            String BlastPercentIdenityToken2;
            String BlastAlignemntLengthToken2;
            String BlastMismatchToken2;
            String BlastGapOpenToken2;
            String BlastQueryStartToken2;
            String BlastQueryEndToken2; 
            String BlastSubjectStartToken2;
            String BlastSubjectEndToken2;
            String BlastEvalueToken2;
            String BlastBitScoreToken2;
            String HeapTopTenLinear;
            String DeReplicateAccessionHolderi;
            String IBlastQueryNameToke;
            String IBlastAcessionNameToken;
            String IplusoneBlastQueryNameToken;
            String IplusoneBlastAcessionNameToken;
            String DeReplicateAccessionHolderiplusone;
            double BlastEvalueDoubleconversion;
            String IBlastQueryNameToken;
            int ReplicateEntries=1;
            int ReplicateEntriesCounter=0;
            int DeReplicatedTopHitCounter=0;
            String BarDelimit = "\\|";
            String CheckForEmpty = "";
            String BlastUniprotSearchToken = "";
            String BlastGIValue = "";
            String BlastGIValue2= "";
            String BlastUniprotSearchToken2= "";
            String SplitValue3 = "";
            String SplitValue2 = "";
            String SplitValue = "";
            //initialize array, initialize sqlLite database
            
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            
            if (blastPorX.equals("blastp")) {
                // purge earlier blastp resutls
                stat.executeUpdate("delete from BlastDbase where TrinityID in (select orf_id from ORF)");
            }
            else {
                // purge earlier blastx results
                stat.executeUpdate("delete from BlastDbase where TrinityID in (select transcript_id from Transcript)");
            }
            

            //Prepare Database
            PreparedStatement prep = conn.prepareStatement("insert into BlastDbase values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);");
           
            
            //Initilaze Array values
            while ((strLine = br.readLine()) != null)   
                {
                    ArrayInitialize++;
                }
            int withsent=ArrayInitialize+2;
            String TotalFile[] = new String[withsent];
            String TopNHitsTotal[] = new String[ArrayInitialize];
            String TopHitsHeapToKeep[] = new String[ArrayInitialize];
            String TopTenUniqueListReport[] = new String[ArrayInitialize];
            String TopTenUniqueHitLinear[]=new String[ArrayInitialize];
            String DeReplicatedBlastOuts[]= new String[ArrayInitialize];
            String ReplicatedBlastEntries[]=new String[ArrayInitialize];
            String ARRAYSENT="SENT";
            // Read in Files
            while(scannertotal.hasNextLine())
                {
                    TotalFile[LineCounter] = scannertotal.nextLine();
                    LineCounter++;
                }
            int SentValue = LineCounter +1;
            TotalFile[SentValue]=ARRAYSENT;
            
            
            //Initilize first value 
            String HeapToKeep = "";
            BlastTokenHolder=TotalFile[0];
            StringTokenizer st = new StringTokenizer(BlastTokenHolder);
            BlastQueryNameToken=st.nextToken();
            BlastAcessionNameToken=st.nextToken();
            
            String[] SplitArray;
            
            SplitArray= BlastAcessionNameToken.split(BarDelimit);
            
            SplitValue=SplitArray[2];
            // Parese Blats from uniport or NR
            if (PrintSent==0)
                {
                    if(CheckForEmpty.equals(SplitValue))
                        {
                            BlastGIValue=SplitArray[2]; 
                            BlastUniprotSearchToken=SplitArray[1];
                        }
                    else
                        {
                            BlastGIValue=SplitArray[2]; 
                            BlastUniprotSearchToken=SplitArray[1];
                        }
                }
            else if (PrintSent==1)
                {
                    BlastGIValue = DatabaseforStore;
                    BlastUniprotSearchToken=SplitArray[1];
                }
            else
                {
                    System.out.println("NoSearchStringSpecified");
                }
            
            BlastPercentIdenityToken=st.nextToken();
            BlastAlignemntLengthToken=st.nextToken();
            BlastMismatchToken=st.nextToken();
            BlastGapOpenToken=st.nextToken();
            BlastQueryStartToken=st.nextToken();
            BlastQueryEndToken=st.nextToken();
            BlastSubjectStartToken=st.nextToken();
            BlastSubjectEndToken=st.nextToken();
            BlastEvalueToken=st.nextToken();
            BlastBitScoreToken=st.nextToken();
            int SameModelSent=0;
            int TonextmodelSENT=0;
            int HeapCounter=0;
            HeapToKeep = BlastQueryNameToken +  "		" + BlastEvalueToken;
            TopNHitsTotal[0]=BlastTokenHolder;
            
            
	        prep.setString(1,BlastQueryNameToken);
			prep.setString(2,BlastAcessionNameToken);
			prep.setString(3,BlastGIValue);
			prep.setString(4,BlastUniprotSearchToken);
			prep.setString(5,BlastQueryStartToken);
			prep.setString(6,BlastQueryEndToken);
			prep.setString(7,BlastSubjectStartToken);
			prep.setString(8,BlastSubjectEndToken);
			prep.setString(9,BlastPercentIdenityToken);
			prep.setString(10,BlastEvalueToken);
			prep.setString(11,BlastBitScoreToken);
		    prep.addBatch();
            //For Lop to run through Blast Entries, compares query to classiffy top hit, limits top hits to 10 diffrent hits, 50 duplicates of each hit to count for replicates
            
            for (int i=1; i<LineCounter; i++)
                {
                    if (ToPrint.equals(ProgressCounterSENT))
                        {
                            if (i%1000 == 0)
                                {
                                    System.out.print("\rProcessing Entry:" + i + "   ");
                                }
                        }
                    
                    strLine= TotalFile[i];
                    boolean check = strLine.equals(ARRAYSENT);	
                    if (!check)
                        {
                            BlastTokenHolder2=TotalFile[i];
                            StringTokenizer st2 = new StringTokenizer(BlastTokenHolder2);
                            BlastQueryNameToken2=st2.nextToken();
                            BlastAcessionNameToken2=st2.nextToken();
                            
                            
                            String[] SplitArray1;
                            SplitArray1= BlastAcessionNameToken2.split(BarDelimit);
                            
                            if(PrintSent==0)
                                {
                                    SplitValue=SplitArray1[2];
                                    if(CheckForEmpty.equals(SplitValue))
                                        {
                                            BlastGIValue2=SplitArray1[2]; 
                                            BlastUniprotSearchToken2=SplitArray1[1];
                                        }
                                    else
                                        {
                                            BlastGIValue2=SplitArray1[2]; 
                                            BlastUniprotSearchToken2=SplitArray1[1];
                                        }
                                } 
                            else if (PrintSent==1)
                                {
                                    BlastGIValue2 = DatabaseforStore;
                                    BlastUniprotSearchToken2=SplitArray1[1];
                                }
                            else
                                {
                                    System.out.println("NoSearchStringSpecified");
                                }
                            
                            
                            
                            BlastPercentIdenityToken2=st2.nextToken();
                            BlastAlignemntLengthToken2=st2.nextToken();
                            BlastMismatchToken2=st2.nextToken();
                            BlastGapOpenToken2=st2.nextToken();
                            BlastQueryStartToken2=st2.nextToken();
                            BlastQueryEndToken2=st2.nextToken();
                            BlastSubjectStartToken2=st2.nextToken();
                            BlastSubjectEndToken2=st2.nextToken();
                            BlastEvalueToken2=st2.nextToken();
                            BlastBitScoreToken2=st2.nextToken();
                            if(BlastQueryNameToken.equals(BlastQueryNameToken2))
                                {
                                    if (BlastAcessionNameToken.equals(BlastAcessionNameToken2))
                                        {
                                            if(TopHitSent>=AccessionCounter)
                                                {
                                                    AccessionCounter++;		   
                                                    TopNHitCounter++;
                                                    TopNHitsTotal[TopNHitCounter] = BlastTokenHolder2; 
                                                    
                                                    BlastQueryNameToken=BlastQueryNameToken2;
                                                    BlastTokenHolder=BlastTokenHolder2;
                                                    BlastAcessionNameToken	= BlastAcessionNameToken2;
                                                }
                                            else
                                                {
                                                    BlastQueryNameToken=BlastQueryNameToken2;
                                                    BlastTokenHolder=BlastTokenHolder2;
                                                    BlastAcessionNameToken	= BlastAcessionNameToken2;
                                                }
                                        }
                                    
                                    else
                                        {
                                            if(TopHitSent>=SentCounter)
                                                {
                                                    SentCounter++;
                                                    AccessionCounter=2;
                                                    TopNHitCounter++;
                                                    TopNHitsTotal[TopNHitCounter] = BlastTokenHolder2; 
                                                    BlastQueryNameToken=BlastQueryNameToken2;
                                                    BlastTokenHolder=BlastTokenHolder2;
                                                    BlastAcessionNameToken	= BlastAcessionNameToken2;
                                                    prep.setString(1,BlastQueryNameToken2);
                                                    prep.setString(2,BlastAcessionNameToken2);
                                                    prep.setString(3,BlastGIValue2);
                                                    prep.setString(4,BlastUniprotSearchToken2);
                                                    prep.setString(5,BlastQueryStartToken2);
                                                    prep.setString(6,BlastQueryEndToken2);
                                                    prep.setString(7,BlastSubjectStartToken2);
                                                    prep.setString(8,BlastSubjectEndToken2);
                                                    prep.setString(9,BlastPercentIdenityToken2);
                                                    prep.setString(10,BlastEvalueToken2);
                                                    prep.setString(11,BlastBitScoreToken2);
                                                    prep.addBatch();
                                                    
                                                }
                                            else
                                                {	
                                                    BlastQueryNameToken=BlastQueryNameToken2;
                                                    BlastTokenHolder=BlastTokenHolder2;
                                                    BlastAcessionNameToken	= BlastAcessionNameToken2;
                                                }	  
                                        }
                                    
                                }
                            
                            else
                                {
                                    TopHitsHeapToKeep[HeapCounter] = HeapToKeep;
                                    TopNHitCounter++;
                                    TopNHitsTotal[TopNHitCounter] = BlastTokenHolder2;
                                    prep.setString(1,BlastQueryNameToken2);
                                    prep.setString(2,BlastAcessionNameToken2);
                                    prep.setString(3,BlastGIValue2);
                                    prep.setString(4,BlastUniprotSearchToken2);
                                    prep.setString(5,BlastQueryStartToken2);
                                    prep.setString(6,BlastQueryEndToken2);
                                    prep.setString(7,BlastSubjectStartToken2);
                                    prep.setString(8,BlastSubjectEndToken2);
                                    prep.setString(9,BlastPercentIdenityToken2);
                                    prep.setString(10,BlastEvalueToken2);
                                    prep.setString(11,BlastBitScoreToken2);
                                    prep.addBatch();
                                    SentCounter=2;
                                    AccessionCounter=2;
                                    HeapCounter++;
                                    HeapToKeep = BlastQueryNameToken2 + "     "+ BlastEvalueToken2;
                                    BlastQueryNameToken=BlastQueryNameToken2;
                                    BlastTokenHolder=BlastTokenHolder2;
                                    BlastAcessionNameToken	= BlastAcessionNameToken2; 
                                }
                            
                        }
                    else
                        {
                            
                            HeapCounter++;
                            TopNHitCounter++;
                            TopNHitsTotal[TopNHitCounter] = BlastTokenHolder;
                            StringTokenizer st4 = new StringTokenizer(BlastTokenHolder);
                            BlastQueryNameToken=st4.nextToken();
                            BlastAcessionNameToken=st4.nextToken();
                            
                            
                            
                            String[] SplitArray3;
                            SplitArray3= BlastAcessionNameToken.split(BarDelimit);
                            
                            SplitValue=SplitArray3[2];
                            if (PrintSent==0)
                                {
                                    if(CheckForEmpty.equals(SplitValue3))
                                        {
                                            BlastGIValue=SplitArray3[2]; 
                                            BlastUniprotSearchToken=SplitArray3[1];
                                        }
                                    else
                                        {
                                            BlastGIValue=SplitArray3[2]; 
                                            BlastUniprotSearchToken=SplitArray3[1];
                                        }
                                }
                            else if (PrintSent==1)
                                {
                                    BlastGIValue = DatabaseforStore;
                                    BlastUniprotSearchToken=SplitArray3[1];
                                }
                            else
                                {
                                }
                            
                            
                            BlastPercentIdenityToken=st4.nextToken();
                            BlastAlignemntLengthToken=st4.nextToken();
                            BlastMismatchToken=st4.nextToken();
                            BlastGapOpenToken=st4.nextToken();
                            BlastQueryStartToken=st4.nextToken();
                            BlastQueryEndToken=st4.nextToken();
                            BlastSubjectStartToken=st4.nextToken();
                            BlastSubjectEndToken=st4.nextToken();
                            BlastEvalueToken=st4.nextToken();
                            BlastBitScoreToken=st4.nextToken();
                            prep.setString(1,BlastQueryNameToken);
                            prep.setString(2,BlastAcessionNameToken);
                            prep.setString(3,BlastAcessionNameToken);
                            prep.setString(4,BlastAcessionNameToken);
                            prep.setString(5,BlastQueryStartToken);
                            prep.setString(6,BlastQueryEndToken);
                            prep.setString(7,BlastSubjectStartToken);
                            prep.setString(8,BlastSubjectEndToken);
                            prep.setString(9,BlastPercentIdenityToken);
                            prep.setString(10,BlastEvalueToken);
                            prep.setString(11,BlastBitScoreToken);
                            prep.addBatch();
                            
                        }
                    
                }
            
            
            conn.setAutoCommit(false);
            prep.executeBatch();
            conn.setAutoCommit(true);
            //Prints data
            if (ToPrint.equals(PrintMYSQLSent))
                {
                    ResultSet rs = stat.executeQuery("select * from BlastDbase;");
                    while (rs.next()) {
                        System.out.println("TrintiyID = " + rs.getString("TrinityID"));
                        System.out.println("FullAccession = " + rs.getString("FullAccession"));
                        System.out.println("DatabaseSource = " + rs.getString("GINumber"));
                        System.out.println("UniprotSearchString = " + rs.getString("UniprotSearchString"));
                        System.out.println("QueryStart = " + rs.getString("QueryStart"));
                        System.out.println("QueryEnd = " + rs.getString("QueryEnd"));
                        System.out.println("HitStart = " + rs.getString("HitStart"));
                        System.out.println("HitEnd = " + rs.getString("HitEnd"));
                        System.out.println("PercentIdentity = " + rs.getString("PercentIdentity"));
                        System.out.println("BitScore = " + rs.getString("BitScore"));
                        System.out.println("Evalue = " + rs.getString("Evalue")); 
                    }
                    
                    
                    
                    
                    
                }	
            
            // Print out final values
            
            in.close();
            conn.close();
            

            System.out.println("Done.");
            System.exit(0);

            
            
            
        }catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);

        }
    }
}
