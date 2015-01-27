import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class TaxonomytoMySQLLite {

    public static void main(String args[]) {

        try {
            // Open Files needed     
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            
            String ToPrint = args[1]; 
            String PrintSent = "verbose";
            String ProgressCounterSENT = "counter";
            String strLine;
            // Set Varibles needed for Parser  
            int ArrayInitialize=0;
            int LineCounter=0;
            int LineCounter1=0;
            int LineCounter2=0;
            int intForCoversion=0;
            String ArrayPostionStringConverted="";
            String BlastNameHolder = "";
            String DatabaseIndexHolder = "";
            String TaxTempHolder = "";
            String TaxValueForCommitt = "";
            String TaxonomyAccesionForCommit = "";
            
            String TaxonomyHolder = "";
            String AccesionToCommit = "";
            
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            
            // clean out in case re-loading
            stat.executeUpdate("delete from TaxonomyIndex");
            
            PreparedStatement prep = conn.prepareStatement("insert into TaxonomyIndex values (?, ?);");
            
            while ((strLine = br.readLine()) != null)   {
                
             
                LineCounter++;
                
                if (ToPrint.equals(ProgressCounterSENT)) {
                    if (LineCounter % 1000 == 0)  {
                        System.out.println("Processed Entry:" + LineCounter);
                    }
                }
                
                StringTokenizer st1 = new StringTokenizer(strLine);
                TaxonomyAccesionForCommit=st1.nextToken(); 
                
                while (st1.hasMoreTokens()) {
                    TaxTempHolder = st1.nextToken(); 
                    TaxValueForCommitt = TaxValueForCommitt + "  " + TaxTempHolder;
                }
                
                prep.setString(1,TaxonomyAccesionForCommit);
                prep.setString(2,TaxValueForCommitt );
                prep.addBatch();
                TaxValueForCommitt= "";
            }
            
            conn.setAutoCommit(false);
            prep.executeBatch();
            conn.setAutoCommit(true);
            
            if (ToPrint.equals(PrintSent)) {
                ResultSet rs = stat.executeQuery("select * from TaxonomyIndex;");
                while (rs.next()) {
                    System.out.println("Accesion = " + rs.getString("NCBITaxonomyAccession"));
                    System.out.println("ArrayIndex = " + rs.getString("TaxonomyValue"));
                }	
            }
            
            //Close the input stream
            in.close();
            
        }
        catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
        }
    }
}


