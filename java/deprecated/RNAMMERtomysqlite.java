import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class RNAMMERtomysqlite {

    public static void main(String args[]) {
        
        String usage = "args: rnammer.gff (counter|verbose)";
        if (args.length != 2) {
            System.err.println("\n\n" + usage + "\n\n");
            System.exit(1);
        }
        
        try {
        
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
            String SignalPIndexHolder = "";
            String UniprotMatchCheck = "";
            int ArrayInitialize2=0;
            String ParsedMascotHolder = "";
            int InCorrectCounter = 0;
            String ParsedMascotIndexCheck = "";
            int MatchFoundflag = 0;
            int MatchFoundCounter = 0;
            int NotFoundCounter = 0;
            String removecomment = "";
            String RNAMMERSeqName = "";
            String RNAMMERSourceToken = "";
            String RNAMMERFeautreToken = "";
            String RNAMMERStartToken = "";
            String RNAMMEREndToken = "";
            String RNAMMERScorerToken = "";
            String RNAMMERStrandToken = "";
            String RNAMMERFrameToken = "";
            String RNAMMERFeatureToken = "";
            //sqllite statement
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");

            Statement stat = conn.createStatement();
            stat.executeUpdate("delete from RNAMMERdata;");

            PreparedStatement prep = conn.prepareStatement("insert into RNAMMERdata values (?, ?, ?, ?, ?, ?, ?);");

            // read files into array
            while ((strLine = br.readLine()) != null) {

                if (strLine.startsWith("#")) {
                    continue;
                }
                
                LineCounter++;
                
                
                if (ToPrint.equals(ProgressCounterSENT)) {
                    System.out.println("Processed Entry:" + LineCounter);
                }
                
                StringTokenizer st1 = new StringTokenizer(strLine);
                    
                RNAMMERSeqName = st1.nextToken();
                RNAMMERSourceToken = st1.nextToken();
                RNAMMERFeautreToken = st1.nextToken();
                RNAMMERStartToken = st1.nextToken();
                RNAMMEREndToken = st1.nextToken();
                RNAMMERScorerToken = st1.nextToken();
                RNAMMERStrandToken = st1.nextToken();
                RNAMMERFrameToken = st1.nextToken();
                RNAMMERFeatureToken = st1.nextToken();
			
                                    
                prep.setString(1,RNAMMERSeqName);
                prep.setString(2,RNAMMERStartToken);
                prep.setString(3,RNAMMEREndToken);
                prep.setString(4,RNAMMERScorerToken);
                prep.setString(5,RNAMMERStrandToken);
				prep.setString(6,RNAMMERFrameToken);
				prep.setString(7,RNAMMERFeatureToken);
                prep.addBatch();	
                
            }
        
            in.close();


            conn.setAutoCommit(false);
            prep.executeBatch();
            
            conn.setAutoCommit(true);
            if (ToPrint.equals(PrintSent)) {
                ResultSet rs = stat.executeQuery("select * from RNAMMERdata;");
                while (rs.next()) {
                    System.out.println("TrinityQuerySequence = " + rs.getString("TrinityQuerySequence"));
                    System.out.println("FeatureStartValue = " + rs.getString("Featurestart"));
                    System.out.println("FeatureEndValue = " + rs.getString("Featureend"));
                    System.out.println("FeatureScoreValue = " + rs.getString("Featurescore"));
                    System.out.println("FeatureStrandValue = " + rs.getString("FeatureStrand"));  
					System.out.println("FeatureFrameValue = " + rs.getString("FeatureFrame"));
                    System.out.println("FeatureRNAMMERPrediction = " + rs.getString("Featureprediction"));						
                }	
            }
            
            
            //Close the input stream
            


            conn.close();

            System.exit(0);

                        
        }
        catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
        }
    }
}

