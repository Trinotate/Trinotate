import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class SignalPtoMYSQLlite {

    public static void main(String args[]) {
        
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
            String SignalPquery_prot_idToken = "";
            String SignalPSourceToken = "";
            String SignalPFeatureToken = "";
            String SignalPStartToken = "";
            String SignalPEndToken = "";
            String SignalPScoreryToken = "";
            String SignalPdot1Token = "";
            String Signaldot2Token = "";
            String SignalPredictionToken = "";
            //sqllite statement
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            stat.executeUpdate("delete from SignalP;");
            

            PreparedStatement prep = conn.prepareStatement("insert into SignalP values (?, ?, ?, ?, ?);");

            // read files into array
            while ((strLine = br.readLine()) != null) {

                if (strLine.startsWith("#")) {
                    continue;
                }
                
                LineCounter++;
                
                
                if (ToPrint.equals(ProgressCounterSENT)) {
                    System.out.print("\rProcessed Entry:" + LineCounter + "  ");
                }
                
                StringTokenizer st1 = new StringTokenizer(strLine);
                    
                SignalPquery_prot_idToken = st1.nextToken();
                SignalPSourceToken = st1.nextToken();
                SignalPFeatureToken = st1.nextToken();
                SignalPStartToken = st1.nextToken();
                SignalPEndToken = st1.nextToken();
                SignalPScoreryToken = st1.nextToken();
                SignalPdot1Token = st1.nextToken();
                Signaldot2Token = st1.nextToken();
                SignalPredictionToken = st1.nextToken();
                                    
                prep.setString(1,SignalPquery_prot_idToken);
                prep.setString(2,SignalPStartToken);
                prep.setString(3,SignalPEndToken);
                prep.setString(4,SignalPScoreryToken);
                prep.setString(5,SignalPredictionToken);
                prep.addBatch();	
                
            }
        
            in.close();


            conn.setAutoCommit(false);
            prep.executeBatch();
            
            conn.setAutoCommit(true);
            if (ToPrint.equals(PrintSent)) {
                ResultSet rs = stat.executeQuery("select * from SignalP;");
                while (rs.next()) {
                    System.out.println("query_prot_idName = " + rs.getString("query_prot_id"));
                    System.out.println("SignalPStart = " + rs.getString("start"));
                    System.out.println("SignalPStop = " + rs.getString("end"));
                    System.out.println("SignalPScore = " + rs.getString("score"));
                    System.out.println("SingalPPrediction = " + rs.getString("prediction"));  
                }	
            }
            
            
            //Close the input stream
            
            conn.close();

            System.out.println("Done.");
            System.exit(0);
            

                        
        }
        catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
            

        }
    }
}

